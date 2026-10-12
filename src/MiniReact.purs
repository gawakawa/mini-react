module MiniReact
  ( VirtualElement(..)
  , Prop(..)
  ) where

import Prelude

import Effect (Effect)
import Web.Event.Event (Event)

data VirtualElement
  = HostComponent String (Array Prop) (Array VirtualElement)
  | HostText String
  | Fragment (Array VirtualElement)

data Prop
  = Property String String
  | Listener String (Event -> Effect Unit)
