module TPM.GraphDB.Graph.Transaction where

import TPM.GraphDB.Prelude hiding (Read, Write)
import qualified TPM.GraphDB.Graph.Node as Node; import TPM.GraphDB.Graph.Node (Node)
import qualified TPM.GraphDB.Graph.Transaction.NodeRefRegistry as NodeRefRegistry; import TPM.GraphDB.Graph.Transaction.NodeRefRegistry (NodeRefRegistry)
import qualified TPM.GraphDB.Graph.Transaction.NodeRef as NodeRef; import TPM.GraphDB.Graph.Transaction.NodeRef (NodeRef)



getRoot :: (Reads t, MonadIO (t n e s)) => t n e s (NodeRef n e s)
getRoot = do
  root <- getRootNode
  registry <- getNodeRefRegistry
  liftIO $ NodeRefRegistry.newNodeRef registry root

newNode :: (Reads t, MonadIO (t n e s)) => n -> t n e s (NodeRef n e s)
newNode value = do
  registry <- getNodeRefRegistry
  liftIO $ do
    node <- Node.new value
    NodeRefRegistry.newNodeRef registry node

getTargets :: (Reads t, MonadIO (t n e s), Hashable e, Eq e) => e -> NodeRef n e s -> t n e s [NodeRef n e s]
getTargets edge refA = do
  registry <- getNodeRefRegistry
  liftIO $ do
    nodeA <- NodeRef.getNode refA
    nodesB <- Node.getTargets nodeA edge
    forM nodesB $ \node -> NodeRefRegistry.newNodeRef registry node

getValue :: (Reads t, MonadIO (t n e s)) => NodeRef n e s -> t n e s n
getValue ref = liftIO $ NodeRef.getNode ref >>= Node.getValue

setValue :: NodeRef n e s -> n -> Write n e s ()
setValue ref value = do
  liftIO $ do
    node <- NodeRef.getNode ref
    Node.setValue node value

insertEdge :: (Hashable e, Eq e) => NodeRef n e s -> e -> NodeRef n e s -> Write n e s ()
insertEdge refA edge refB = do
  liftIO $ do
    nodeA <- NodeRef.getNode refA
    nodeB <- NodeRef.getNode refB
    Node.insertEdge nodeA edge nodeB

deleteEdge :: (Hashable e, Eq e) => NodeRef n e s -> e -> NodeRef n e s -> Write n e s ()
deleteEdge refA edge refB = do
  liftIO $ do
    nodeA <- NodeRef.getNode refA
    nodeB <- NodeRef.getNode refB
    Node.deleteEdge nodeA edge nodeB



-- | Support for read operations of transaction.
class Reads t where
  getRootNode :: t n e s (Node n e)
  getNodeRefRegistry :: t n e s (NodeRefRegistry n e)

instance Reads Write where
  getRootNode = Write $ \z _ -> return z
  getNodeRefRegistry = Write $ \_ z -> return z

instance Reads Read where
  getRootNode = Read $ \z _ -> return z
  getNodeRefRegistry = Read $ \_ z -> return z



-- |
-- A write and read transaction. Only a single write-transaction executes at a time.
-- 
-- Here the /s/ is a state-thread making the escape of node-refs from transaction
-- impossible. Much inspired by the realization of 'ST'.
-- 
newtype Write n e s r = Write (Node n e -> NodeRefRegistry n e -> IO r)

instance MonadIO (Write n e s) where
  liftIO io = Write $ \_ _ -> io

instance Monad (Write n e s) where
  return a = Write $ \_ _ -> return a
  writeA >>= aToWriteB = Write rootToRegToIO where
    rootToRegToIO tag reg = ioA >>= aToIOB where
      Write rootToRegToIOA = writeA
      ioA = rootToRegToIOA tag reg
      aToIOB a = ioB where
        Write rootToRegToIOB = aToWriteB a
        ioB = rootToRegToIOB tag reg

instance Applicative (Write n e s) where
  pure = return
  (<*>) = ap

instance Functor (Write n e s) where
  fmap = liftM

runWrite :: Node n e -> (forall s. Write n e s r) -> IO r
runWrite root (Write run) = NodeRefRegistry.new >>= run root



-- |
-- A read-only transaction. Gets executed concurrently.
-- 
-- Here the /s/ is a state-thread making the escape of node-refs from transaction
-- impossible. Much inspired by the realization of 'ST'.
-- 
newtype Read n e s r = Read (Node n e -> NodeRefRegistry n e -> IO r)

instance MonadIO (Read n e s) where
  liftIO io = Read $ \_ _ -> io

instance Monad (Read n e s) where
  return a = Read $ \_ _ -> return a
  readA >>= aToReadB = Read rootToRegToIO where
    rootToRegToIO tag reg = ioA >>= aToIOB where
      Read rootToRegToIOA = readA
      ioA = rootToRegToIOA tag reg
      aToIOB a = ioB where
        Read rootToRegToIOB = aToReadB a
        ioB = rootToRegToIOB tag reg

instance Applicative (Read n e s) where
  pure = return
  (<*>) = ap

instance Functor (Read n e s) where
  fmap = liftM

runRead :: Node n e -> (forall s. Read n e s r) -> IO r
runRead root (Read run) = NodeRefRegistry.new >>= run root

