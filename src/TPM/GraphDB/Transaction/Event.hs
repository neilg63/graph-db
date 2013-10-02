-- |
-- Transaction-tags allow logging of transactions.
module TPM.GraphDB.Transaction.Event where

import TPM.GraphDB.Prelude hiding (Read, Write)
import qualified TPM.GraphDB.Transaction as Transaction
import qualified TPM.GraphDB.DB as DB; import TPM.GraphDB.DB (DB)
import qualified TPM.GraphDB.Node as Node; import TPM.GraphDB.Node (Node)
import qualified TPM.GraphDB.Dispatcher as Dispatcher; import TPM.GraphDB.Dispatcher (Dispatcher)

import qualified Data.SafeCopy as SafeCopy; import Data.SafeCopy (SafeCopy)
import qualified Data.Serialize as Cereal



class Event t where
  type EventTag t
  type EventTransaction t
  type EventResult t
  transaction :: t -> (EventTransaction t) (EventTag t) s (EventResult t)

run :: (Event t, Transaction.Transaction (EventTransaction t)) => DB (EventTag t) -> t -> IO (EventResult t)
run db event = Transaction.run db $ transaction event




