{-# LANGUAGE DataKinds, MultiParamTypeClasses, RankNTypes, ScopedTypeVariables, TypeFamilies, TypeOperators, UndecidableInstances #-}
module Rendering.Imports
( renderModuleTerms
, renderToImports
) where

import Analysis.Declaration
import Data.Aeson
import Data.Blob
import Data.Maybe (mapMaybe)
import Data.Record
import Data.Span
import Data.Term
import GHC.Generics
import System.FilePath.Posix (takeBaseName)
import qualified Data.Text as T
import qualified Data.Map as Map
import Rendering.TOC (termTableOfContentsBy, declaration, getDeclaration, toCategoryName)


-- | Render terms to final JSON structure.
renderModuleTerms :: [Value] -> Map.Map T.Text Value
renderModuleTerms = Map.singleton "modules" . toJSON

-- | Render a 'Term' to a list of symbols (See 'Symbol').
renderToImports :: (HasField fields (Maybe Declaration), HasField fields Span, Foldable f, Functor f) => Blob -> Term f (Record fields) -> [Value]
renderToImports Blob{..} term = [toJSON (termToC blobPath term)]
  where
    termToC :: (HasField fields (Maybe Declaration), HasField fields Span, Foldable f, Functor f) => FilePath -> Term f (Record fields) -> Module
    termToC path term = let toc = termTableOfContentsBy declaration term in Module
      { moduleName = T.pack (takeBaseName path)
      , modulePath = T.pack path
      , moduleLanguage = T.pack . show <$> blobLanguage
      , moduleImports = mapMaybe importSummary toc
      , moduleDeclarations = mapMaybe declarationSummary toc
      }

declarationSummary :: (HasField fields (Maybe Declaration), HasField fields Span) => Record fields -> Maybe SymbolDeclaration
declarationSummary record = case getDeclaration record of
  Just declaration | FunctionDeclaration{} <- declaration -> Just (makeSymbolDeclaration declaration)
                   | MethodDeclaration{} <- declaration -> Just (makeSymbolDeclaration declaration)
  _ -> Nothing
  where makeSymbolDeclaration declaration = SymbolDeclaration
          { declarationName = declarationIdentifier declaration
          , declarationKind = toCategoryName declaration
          , declarationSpan = getField record
          }

importSummary :: (HasField fields (Maybe Declaration), HasField fields Span) => Record fields -> Maybe SymbolImport
importSummary record = case getDeclaration record of
  Just ImportDeclaration{..} -> Just SymbolImport
    { symbolName = declarationIdentifier
    , symbolSpan = getField record
    }
  _ -> Nothing

data Module = Module
  { moduleName :: T.Text
  , modulePath :: T.Text
  , moduleLanguage :: Maybe T.Text
  , moduleImports :: [SymbolImport]
  , moduleDeclarations :: [SymbolDeclaration]
  -- , moduleReferences :: [SymbolReferences]
  } deriving (Generic, Eq, Show)

instance ToJSON Module where
  toJSON Module{..} = object [ "name" .= moduleName
                             , "path" .= modulePath
                             , "langauge" .= moduleLanguage
                             , "imports" .= moduleImports
                             , "declarations" .= moduleDeclarations
                             ]

data SymbolDeclaration = SymbolDeclaration
  { declarationName :: T.Text
  , declarationKind :: T.Text
  , declarationSpan :: Span
  } deriving (Generic, Eq, Show)

instance ToJSON SymbolDeclaration where
  toJSON SymbolDeclaration{..} = object [ "name" .= declarationName
                                        , "kind" .= declarationKind
                                        , "span" .= declarationSpan
                                        ]

data SymbolImport = SymbolImport
  { symbolName :: T.Text
  , symbolSpan :: Span
  } deriving (Generic, Eq, Show)

instance ToJSON SymbolImport where
  toJSON SymbolImport{..} = object [ "name" .= symbolName
                                   , "span" .= symbolSpan ]
