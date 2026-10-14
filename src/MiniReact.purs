module MiniReact
  ( VirtualElement(..)
  , Prop(..)
  , Component
  , component
  , useState
  , render
  ) where

import Prelude

import Data.Array ((!!), last, length)
import Data.Foldable (for_, traverse_)
import Data.Maybe (Maybe(..), fromMaybe, isJust, isNothing)
import Data.Traversable (for)
import Data.Tuple.Nested ((/\), type (/\))
import Effect (Effect, whileE)
import Effect.Exception (throw)
import Effect.Ref (Ref)
import Effect.Ref as Ref
import Effect.Unsafe (unsafePerformEffect)
import Unsafe.Coerce (unsafeCoerce)
import Web.DOM.Document (Document, createElement, createTextNode)
import Web.DOM.Element (Element)
import Web.DOM.Element as Element
import Web.DOM.Node (Node, appendChild, firstChild, insertBefore, nextSibling, parentNode, removeChild, setNodeValue)
import Web.DOM.Text as Text
import Web.Event.Event (EventType(..))
import Web.Event.EventTarget (EventListener, addEventListener, removeEventListener)
import Web.HTML (window)
import Web.HTML.HTMLDocument (toDocument)
import Web.HTML.Window (document)

data VirtualElement
  = HostComponent String (Array Prop) (Array VirtualElement)
  | HostText String
  | Fragment (Array VirtualElement)
  | FunctionComponent Component

newtype Component = Component (forall r. (forall props. (props -> Effect VirtualElement) -> props -> r) -> r)

component :: forall props. (props -> Effect VirtualElement) -> props -> VirtualElement
component renderer props = FunctionComponent $ Component \k -> k renderer props

runComponent :: Component -> Effect VirtualElement
runComponent (Component c) = c \renderer props -> renderer props

sameComponent :: Component -> Component -> Boolean
sameComponent (Component a) (Component b) = a \ra _ -> b \rb _ -> unsafeRefEq ra rb

data Prop
  = Property String String
  | Listener String EventListener

data EffectTag = Update | Placement

newtype Fiber = Fiber (Ref FiberRec)

type FiberRec =
  { vnode :: VirtualElement
  , dom :: Maybe Node
  , effectTag :: Maybe EffectTag
  , parent :: Maybe Fiber
  , child :: Maybe Fiber
  , sibling :: Maybe Fiber
  , alternate :: Maybe Fiber
  , hooks :: Array Hook
  }

-- The state type of each hook is erased; the hooks call-order rule is what
-- guarantees fromHookState gets back the type that toHookState put in.
data HookState

type Hook = Ref { state :: HookState, queue :: Array HookState }

toHookState :: forall s. s -> HookState
toHookState = unsafeCoerce

fromHookState :: forall s. HookState -> s
fromHookState = unsafeCoerce

createFiber :: FiberRec -> Effect Fiber
createFiber rec = Fiber <$> Ref.new rec

readFiber :: Fiber -> Effect FiberRec
readFiber (Fiber ref) = Ref.read ref

modifyFiber :: Fiber -> (FiberRec -> FiberRec) -> Effect Unit
modifyFiber (Fiber ref) f = Ref.modify_ f ref

wipRoot :: Ref (Maybe Fiber)
wipRoot = unsafePerformEffect $ Ref.new Nothing

currentRoot :: Ref (Maybe Fiber)
currentRoot = unsafePerformEffect $ Ref.new Nothing

nextUnitOfWork :: Ref (Maybe Fiber)
nextUnitOfWork = unsafePerformEffect $ Ref.new Nothing

deletions :: Ref (Array Fiber)
deletions = unsafePerformEffect $ Ref.new []

wipFiber :: Ref (Maybe Fiber)
wipFiber = unsafePerformEffect $ Ref.new Nothing

hookIndex :: Ref Int
hookIndex = unsafePerformEffect $ Ref.new 0

foreign import setProperty :: String -> String -> Element -> Effect Unit

foreign import unsafeRefEq :: forall a b. a -> b -> Boolean

type Deadline = { timeRemaining :: Effect Number }

foreign import scheduleWork :: (Deadline -> Effect Unit) -> Effect Unit

getDocument :: Effect Document
getDocument = do
  w <- window
  toDocument <$> document w

updateDOM :: Element -> Array Prop -> Array Prop -> Effect Unit
updateDOM dom prevProps nextProps = do
  for_ prevProps case _ of
    Property key _ -> setProperty key "" dom
    Listener event l -> removeEventListener (EventType event) l false target
  for_ nextProps case _ of
    Property key value -> setProperty key value dom
    Listener event l -> addEventListener (EventType event) l false target
  where
  target = Element.toEventTarget dom

createDOM :: VirtualElement -> Effect (Maybe Node)
createDOM = case _ of
  HostComponent tag props _ -> do
    doc <- getDocument
    el <- createElement tag doc
    updateDOM el [] props
    pure $ Just $ Element.toNode el
  HostText text -> do
    doc <- getDocument
    t <- createTextNode text doc
    pure $ Just $ Text.toNode t
  Fragment _ -> pure Nothing
  FunctionComponent _ -> pure Nothing

reconcileChildren :: Fiber -> Array VirtualElement -> Effect Unit
reconcileChildren wip elements = do
  { alternate } <- readFiber wip
  oldChild <- case alternate of
    Nothing -> pure Nothing
    Just alt -> _.child <$> readFiber alt
  go 0 oldChild Nothing
  where
  go index oldFiber prevSibling =
    when (index < length elements || isJust oldFiber) do
      old <- for oldFiber \fiber -> { fiber, rec: _ } <$> readFiber fiber
      let
        element = elements !! index
        isSameType = case old, element of
          Just o, Just el -> sameType o.rec.vnode el
          _, _ -> false
      newFiber <- case old, element of
        Just o, Just el | isSameType -> Just <$> createFiber
          { vnode: el
          , dom: o.rec.dom
          , effectTag: Just Update
          , parent: Just wip
          , child: Nothing
          , sibling: Nothing
          , alternate: Just o.fiber
          , hooks: []
          }
        _, Just el -> Just <$> createFiber
          { vnode: el
          , dom: Nothing
          , effectTag: Just Placement
          , parent: Just wip
          , child: Nothing
          , sibling: Nothing
          , alternate: Nothing
          , hooks: []
          }
        _, Nothing -> pure Nothing
      unless isSameType $ for_ old \o -> Ref.modify_ (_ <> [ o.fiber ]) deletions
      if index == 0 then modifyFiber wip _ { child = newFiber }
      else for_ prevSibling \p -> modifyFiber p _ { sibling = newFiber }
      go (index + 1) (old >>= _.rec.sibling) newFiber

sameType :: VirtualElement -> VirtualElement -> Boolean
sameType = case _, _ of
  HostComponent a _ _, HostComponent b _ _ -> a == b
  HostText _, HostText _ -> true
  Fragment _, Fragment _ -> true
  FunctionComponent a, FunctionComponent b -> sameComponent a b
  _, _ -> false

render :: VirtualElement -> Element -> Effect Unit
render element container = do
  root <- createFiber
    { vnode: HostComponent "div" [] [ element ]
    , dom: Just $ Element.toNode container
    , effectTag: Nothing
    , parent: Nothing
    , child: Nothing
    , sibling: Nothing
    , alternate: Nothing
    , hooks: []
    }
  Ref.write Nothing currentRoot
  Ref.write (Just root) wipRoot
  Ref.write (Just root) nextUnitOfWork
  Ref.write [] deletions
  scheduleWork workLoop

workLoop :: Deadline -> Effect Unit
workLoop deadline = do
  whileE canWork do
    next <- Ref.read nextUnitOfWork
    for_ next \fiber -> do
      n <- performUnitOfWork fiber
      Ref.write n nextUnitOfWork
  next <- Ref.read nextUnitOfWork
  wip <- Ref.read wipRoot
  when (isNothing next && isJust wip) commitRoot
  scheduleWork workLoop
  where
  canWork = do
    next <- Ref.read nextUnitOfWork
    remaining <- deadline.timeRemaining
    pure $ isJust next && remaining > 1.0

commitRoot :: Effect Unit
commitRoot = do
  ds <- Ref.read deletions
  for_ ds commitDeletion
  wip <- Ref.read wipRoot
  for_ wip \root -> do
    rec <- readFiber root
    for_ rec.dom \dom -> commitWork dom Nothing rec.child
    modifyFiber root _ { alternate = Nothing }
    Ref.write (Just root) currentRoot
  Ref.write Nothing wipRoot

-- Commits a fiber and its following siblings into parentDom. prev is the last
-- DOM node already in place in parentDom; returns the last one after this run.
commitWork :: Node -> Maybe Node -> Maybe Fiber -> Effect (Maybe Node)
commitWork parentDom prev = case _ of
  Nothing -> pure prev
  Just fiber -> do
    rec <- readFiber fiber
    lastPlaced <- case rec.dom of
      Nothing -> commitWork parentDom prev rec.child
      Just dom -> do
        case rec.effectTag of
          Just Placement -> placeAfter parentDom prev dom
          Just Update -> commitUpdate dom rec
          Nothing -> pure unit
        void $ commitWork dom Nothing rec.child
        pure $ Just dom
    -- Drop the link to the previous tree so old trees can be garbage collected.
    modifyFiber fiber _ { alternate = Nothing }
    commitWork parentDom lastPlaced rec.sibling

placeAfter :: Node -> Maybe Node -> Node -> Effect Unit
placeAfter parentDom prev dom = do
  next <- case prev of
    Nothing -> firstChild parentDom
    Just p -> nextSibling p
  case next of
    Just n -> insertBefore dom n parentDom
    Nothing -> appendChild dom parentDom

commitUpdate :: Node -> FiberRec -> Effect Unit
commitUpdate dom rec = for_ rec.alternate \alt -> do
  old <- readFiber alt
  case old.vnode, rec.vnode of
    HostComponent _ prevProps _, HostComponent _ nextProps _ ->
      for_ (Element.fromNode dom) \el -> updateDOM el prevProps nextProps
    HostText _, HostText text -> setNodeValue text dom
    _, _ -> pure unit

commitDeletion :: Fiber -> Effect Unit
commitDeletion fiber = do
  rec <- readFiber fiber
  case rec.dom of
    Just dom -> do
      parent <- parentNode dom
      for_ parent $ removeChild dom
    Nothing -> go rec.child
  where
  go = traverse_ \f -> do
    commitDeletion f
    { sibling } <- readFiber f
    go sibling

performUnitOfWork :: Fiber -> Effect (Maybe Fiber)
performUnitOfWork fiber = do
  rec <- readFiber fiber
  let
    ensureDOM = when (isNothing rec.dom) do
      dom <- createDOM rec.vnode
      modifyFiber fiber _ { dom = dom }
  case rec.vnode of
    FunctionComponent c -> do
      Ref.write (Just fiber) wipFiber
      modifyFiber fiber _ { hooks = [] }
      Ref.write 0 hookIndex
      child <- runComponent c
      reconcileChildren fiber [ child ]
    HostComponent _ _ children -> do
      ensureDOM
      reconcileChildren fiber children
    HostText _ -> ensureDOM
    Fragment children -> reconcileChildren fiber children
  nextFiber fiber

nextFiber :: Fiber -> Effect (Maybe Fiber)
nextFiber fiber = do
  { child } <- readFiber fiber
  case child of
    Just c -> pure $ Just c
    Nothing -> climb fiber
  where
  climb f = do
    { sibling, parent } <- readFiber f
    case sibling, parent of
      Just s, _ -> pure $ Just s
      Nothing, Just p -> climb p
      Nothing, Nothing -> pure Nothing

useState :: forall s. s -> Effect (s /\ (s -> Effect Unit))
useState initial = do
  fiber <- Ref.read wipFiber >>= case _ of
    Nothing -> throw "useState called outside a function component"
    Just f -> pure f
  { alternate } <- readFiber fiber
  index <- Ref.read hookIndex
  oldHook <- case alternate of
    Nothing -> pure Nothing
    Just alt -> do
      { hooks } <- readFiber alt
      pure $ hooks !! index
  hook <- case oldHook of
    Just h -> pure h
    Nothing -> Ref.new { state: toHookState initial, queue: [] }
  Ref.modify_ (\h -> { state: fromMaybe h.state $ last h.queue, queue: [] }) hook
  modifyFiber fiber \rec -> rec { hooks = rec.hooks <> [ hook ] }
  Ref.modify_ (_ + 1) hookIndex
  { state } <- Ref.read hook
  let
    setState value = do
      Ref.modify_ (\h -> h { queue = h.queue <> [ toHookState value ] }) hook
      current <- Ref.read currentRoot
      for_ current \root -> do
        { vnode, dom } <- readFiber root
        newRoot <- createFiber
          { vnode
          , dom
          , effectTag: Nothing
          , parent: Nothing
          , child: Nothing
          , sibling: Nothing
          , alternate: Just root
          , hooks: []
          }
        Ref.write (Just newRoot) wipRoot
        Ref.write (Just newRoot) nextUnitOfWork
        Ref.write [] deletions
        Ref.write Nothing currentRoot
  pure $ fromHookState state /\ setState
