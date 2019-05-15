{-# LANGUAGE KindSignatures      #-}
{-# LANGUAGE ScopedTypeVariables #-}

module CoffeeMachineTests (stateMachineTests) where

import qualified CoffeeMachine as C
import           Control.Lens (view)
import           Control.Monad.IO.Class (MonadIO)
import           Data.Kind (Type)
import           Hedgehog
import qualified Hedgehog.Gen as Gen
import qualified Hedgehog.Range as Range
import           Test.Tasty (TestTree)
import           Test.Tasty.Hedgehog (testProperty)

data DrinkType = Coffee | HotChocolate | Tea
newtype Model (v :: Type -> Type) = Model DrinkType

-- You will need to define data types for the SetDrinkTea and
-- SetDrinkHotChocolate commands, along with HTraversable instances.

-- input type
data SetDrinkCoffee (v :: Type -> Type) = SetDrinkCoffee deriving Show

instance HTraversable SetDrinkCoffee where
  htraverse _ _ = pure SetDrinkCoffee

data SetDrinkTea (v :: Type -> Type) = SetDrinkTea deriving Show

instance HTraversable SetDrinkTea where
  htraverse _ _ = pure SetDrinkTea

data SetDrinkHotChocolate (v :: Type -> Type) = SetDrinkHotChocolate deriving Show

instance HTraversable SetDrinkHotChocolate where
  htraverse _ _ = pure SetDrinkHotChocolate

cSetDrinkCoffee
  :: forall g m. (MonadGen g, MonadTest m, MonadIO m)
  => C.Machine
  -> Command g m Model
cSetDrinkCoffee mach = Command gen exec
  [ Update $ \_ _ _ -> Model Coffee
  , Ensure $ \_ _ _ drink -> case drink of
      C.Coffee{} -> success
      _ -> failure
  ]
  where
    gen :: Model Symbolic -> Maybe (g (SetDrinkCoffee Symbolic))
    gen _ = Just $ pure SetDrinkCoffee

    exec :: SetDrinkCoffee Concrete -> m C.Drink
    exec _ = do
      C.coffee mach
      view C.drinkSetting <$> C.peek mach

-- You will need to implement these two command generators. Do not
-- copy and change cSetDrinkCoffee without first working through the
-- types. Replace `undefined` with a typed hole and pay attention to
-- the type of each argument.

cSetDrinkHotChocolate
  :: forall g m. (MonadGen g, MonadTest m, MonadIO m)
  => C.Machine
  -> Command g m Model
cSetDrinkHotChocolate machine = Command gen exec
  [
    Update $ \_ _ _ -> Model HotChocolate
  , Ensure $ \_ _ _ drink -> case drink of
      C.HotChocolate -> success
      _ -> failure
  ]
  where
    gen :: Model Symbolic -> Maybe (g (SetDrinkHotChocolate Symbolic))
    gen _ = Just $ pure SetDrinkHotChocolate

    exec :: SetDrinkHotChocolate Concrete -> m C.Drink
    exec _ = do
      C.hotChocolate machine
      view C.drinkSetting <$> C.peek machine

cSetDrinkTea
  :: forall g m. (MonadGen g, MonadTest m, MonadIO m)
  => C.Machine
  -> Command g m Model
cSetDrinkTea machine = Command gen exec
  [
    Update $ \_ _ _ -> Model Tea
  , Ensure $ \_ _ _ drink -> case drink of
      C.Tea{} -> success
      _ -> failure
  ]
  where
    gen :: Model Symbolic -> Maybe (g (SetDrinkTea Symbolic))
    gen _ = Just $ pure SetDrinkTea

    exec :: SetDrinkTea Concrete -> m C.Drink
    exec _ = do
      C.tea machine
      view C.drinkSetting <$> C.peek machine

stateMachineTests :: TestTree
stateMachineTests = testProperty "State Machine Tests" . property $ do
  mach <- C.newMachine

  let initialModel = Model Coffee
      commands = ($ mach) <$>
        [ cSetDrinkCoffee
        , cSetDrinkHotChocolate
        , cSetDrinkTea
        ]

  actions <- forAll $ Gen.sequential (Range.linear 1 100) initialModel commands
  C.reset mach
  executeSequential initialModel actions
