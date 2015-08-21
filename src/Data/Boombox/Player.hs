{-# LANGUAGE Rank2Types, LambdaCase, BangPatterns, DeriveFunctor #-}
module Data.Boombox.Player where
import Control.Monad
import Control.Monad.Trans.Class
import Control.Applicative
import Data.Semigroup

data Decoder e s m a = Done [s] a
  | Partial (s -> Decoder e s m a)
  | Failed !e
  | Eff (m (Decoder e s m a))
  deriving Functor

newtype PlayerT e s m a = PlayerT { unPlayerT :: forall r. s -> (s -> a -> Decoder e s m r) -> Decoder e s m r }

instance Functor (PlayerT e s m) where
  fmap = liftM

instance Applicative (PlayerT e s m) where
  pure = return
  (<*>) = ap

instance Monad (PlayerT e s m) where
  return a = PlayerT $ \s cont -> cont s a
  m >>= k = PlayerT $ \s cont -> unPlayerT m s $ \s' a -> unPlayerT (k a) s' cont

instance MonadTrans (PlayerT e s) where
  lift m = PlayerT $ \s cont -> Eff $ liftM (cont s) m

failPlayer :: e -> PlayerT e s m a
failPlayer e = PlayerT $ \_ _ -> Failed e

instance (Monoid e, Functor m) => Alternative (PlayerT e s m) where
  empty = failPlayer mempty
  p <|> q = PlayerT $ \s cont -> go [] (unPlayerT p s cont) (unPlayerT q s cont) where
    go _ (Done s a) _ = Done s a
    go ss (Partial f) t = Partial $ \s -> go (s : ss) (f s) t
    go ss (Eff m) t = Eff $ fmap (go ss `flip` t) m
    go ss (Failed e) t = supplyDecoder (reverse ss) t

runPlayerT :: PlayerT e s m a -> Decoder e s m a
runPlayerT m = Partial $ \i -> unPlayerT m i (Done . pure)

consuming :: (Semigroup s, Functor m)
  => (s -> m (Maybe (a, s)))
  -> PlayerT e s m a
consuming m = PlayerT $ \s cont -> Eff $ flip fmap (m s) $ \case
  Nothing -> Partial (\t -> let !u = s <> t in unPlayerT (consuming m) u cont)
  Just (a, s') -> cont s' a
