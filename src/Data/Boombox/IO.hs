module Data.Boombox.IO where

import Data.Boombox.Tape
import Control.Monad.IO.Class
import qualified System.IO as IO
import qualified Data.ByteString as BS
import Data.Int

hGetContentsN :: MonadIO m => Int -> IO.Handle -> Vinyl Int64 m BS.ByteString
hGetContentsN n h = Effect $ go 0 where
  go i = do
    c <- liftIO $ BS.hGetSome h n
    let l = BS.length c
    return $ if l <= 0
      then Yield [] $ fmap Effect $ Needle i $ maybe (go i) go
      else Yield [c] $ Needle i $ maybe
        (Effect $ go (i + fromIntegral l))
        (\j -> Effect $ liftIO (IO.hSeek h IO.AbsoluteSeek (fromIntegral j)) >> go j)

hGetContents :: MonadIO m => IO.Handle -> Vinyl Int64 m BS.ByteString
hGetContents = hGetContentsN 4080