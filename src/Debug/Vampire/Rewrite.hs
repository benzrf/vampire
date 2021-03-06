module Debug.Vampire.Rewrite (rewriteFile, wrapExp) where

import Language.Haskell.Exts
import Data.Generics.Uniplate.Data (descend, descendBi)

rewriteFile :: String -> Maybe String
rewriteFile code =
  case parse code :: ParseResult Module of
    ParseOk mod -> Just $ prettyPrint $ addHeader $ descendBi rewrite mod
    _           -> Nothing

addHeader :: Module -> Module
addHeader (Module loc name prag warn _ imports decls) =
  Module loc name (implicit:prag) warn Nothing (trace:imports) decls
    where implicit = LanguagePragma (SrcLoc {srcFilename = "<unknown>.hs", srcLine = 1, srcColumn = 1}) [Ident "ImplicitParams"]
          trace    = ImportDecl {importLoc = SrcLoc {srcFilename = "<unknown>.hs", srcLine = 5, srcColumn = 1}, importModule = ModuleName "Debug.Vampire.Trace", importQualified = False, importSrc = False, importPkg = Nothing, importAs = Nothing, importSpecs = Nothing}

-- TODO: replace ugly pasted literal with something more sensible
rewrite :: Exp -> Exp
rewrite exp = Let (BDecls [PatBind (SrcLoc {srcFilename = "<unknown>.hs", srcLine = 1, srcColumn = 5}) (PVar (Ident "vResultStruct")) Nothing (UnGuardedRhs (App (Var (UnQual (Ident "vNewExprStruct"))) (Lit (String (prettyPrint exp))))) (BDecls []),PatBind (SrcLoc {srcFilename = "<unknown>.hs", srcLine = 2, srcColumn = 5}) (PVar (Ident "vResult")) Nothing (UnGuardedRhs (Paren (Let (BDecls [PatBind (SrcLoc {srcFilename = "<unknown>.hs", srcLine = 2, srcColumn = 21}) (PVar (Ident "?vCtx")) Nothing (UnGuardedRhs (Var (UnQual (Ident "vResultStruct")))) (BDecls [])]) (descend rewrite exp)))) (BDecls [])]) (App (App (App (Var (UnQual (Ident "vLog"))) (Var (UnQual (Ident "?vCtx")))) (Var (UnQual (Ident "vResult")))) (Var (UnQual (Ident "vResultStruct"))))

{-
rewrite expr = AST for this:
  let resultStruct = newExprStruct
      result = (let ?ctx = resultStruct in [splice expr in])
  in (log ?ctx result resultStruct) `seq` result
-}

wrapExp' :: String -> Exp -> Exp
wrapExp' wrapper exp = App (Var (UnQual (Ident wrapper))) (Paren (Lambda (SrcLoc {srcFilename = "<unknown>.hs", srcLine = 1, srcColumn = 11}) [PWildCard] exp))

wrapExp :: String -> String -> Maybe String
wrapExp wrapper code = case parseExp code of
  ParseOk exp -> Just $ prettyPrint $ wrapExp' wrapper exp
  _           -> Nothing

