{-
Copyright (C) 2006-8 John MacFarlane <jgm@berkeley.edu>

This program is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 2 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
-}

{- |
   Module      : Text.Pandoc.Readers.HTML
   Copyright   : Copyright (C) 2006-8 John MacFarlane
   License     : GNU GPL, version 2 or above 

   Maintainer  : John MacFarlane <jgm@berkeley.edu>
   Stability   : alpha 
   Portability : portable

Conversion of HTML to 'Pandoc' document.
-}
module Text.Pandoc.Readers.HTML ( 
                                 readHtml, 
                                 rawHtmlInline, 
                                 rawHtmlBlock, 
                                 anyHtmlBlockTag, 
                                 anyHtmlInlineTag,  
                                 anyHtmlTag,
                                 anyHtmlEndTag,
                                 htmlEndTag,
                                 extractTagType,
                                 htmlBlockElement 
                                ) where

import Text.ParserCombinators.Parsec
import Text.Pandoc.Definition
import Text.Pandoc.Shared 
import Text.Pandoc.CharacterReferences ( decodeCharacterReferences )
import Data.Maybe ( fromMaybe )
import Data.List ( takeWhile, dropWhile, isPrefixOf, isSuffixOf )
import Data.Char ( toLower, isAlphaNum )

-- | Convert HTML-formatted string to 'Pandoc' document.
readHtml :: ParserState   -- ^ Parser state
         -> String        -- ^ String to parse
         -> Pandoc
readHtml = readWith parseHtml

--
-- Constants
--

eitherBlockOrInline = ["applet", "button", "del", "iframe", "ins",
                  "map", "area", "object"]

inlineHtmlTags = ["a", "abbr", "acronym", "b", "basefont", "bdo", "big",
                  "br", "cite", "code", "dfn", "em", "font", "i", "img",
                  "input", "kbd", "label", "q", "s", "samp", "select",
                  "small", "span", "strike", "strong", "sub", "sup",
                  "textarea", "tt", "u", "var"] ++ eitherBlockOrInline

blockHtmlTags = ["address", "blockquote", "center", "dir", "div",
                 "dl", "fieldset", "form", "h1", "h2", "h3", "h4",
                 "h5", "h6", "hr", "isindex", "menu", "noframes",
                 "noscript", "ol", "p", "pre", "table", "ul", "dd",
                 "dt", "frameset", "li", "tbody", "td", "tfoot",
                 "th", "thead", "tr", "script"] ++ eitherBlockOrInline

sanitaryTags = ["a", "abbr", "acronym", "address", "area", "b", "big",
                "blockquote", "br", "button", "caption", "center",
                "cite", "code", "col", "colgroup", "dd", "del", "dfn",
                "dir", "div", "dl", "dt", "em", "fieldset", "font",
                "form", "h1", "h2", "h3", "h4", "h5", "h6", "hr",
                "i", "img", "input", "ins", "kbd", "label", "legend",
                "li", "map", "menu", "ol", "optgroup", "option", "p",
                "pre", "q", "s", "samp", "select", "small", "span",
                "strike", "strong", "sub", "sup", "table", "tbody",
                "td", "textarea", "tfoot", "th", "thead", "tr", "tt",
                "u", "ul", "var"]

sanitaryAttributes = ["abbr", "accept", "accept-charset",
                      "accesskey", "action", "align", "alt", "axis",
                      "border", "cellpadding", "cellspacing", "char",
                      "charoff", "charset", "checked", "cite", "class",
                      "clear", "cols", "colspan", "color", "compact",
                      "coords", "datetime", "dir", "disabled",
                      "enctype", "for", "frame", "headers", "height",
                      "href", "hreflang", "hspace", "id", "ismap",
                      "label", "lang", "longdesc", "maxlength", "media",
                      "method", "multiple", "name", "nohref", "noshade",
                      "nowrap", "prompt", "readonly", "rel", "rev",
                      "rows", "rowspan", "rules", "scope", "selected",
                      "shape", "size", "span", "src", "start",
                      "summary", "tabindex", "target", "title", "type",
                      "usemap", "valign", "value", "vspace", "width"]

--
-- HTML utility functions
--

-- | Returns @True@ if sanitization is specified and the specified tag is 
--  not on the sanitized tag list.
unsanitaryTag tag = do
  st <- getState
  if stateSanitizeHTML st && not (tag `elem` sanitaryTags)
     then return True
     else return False

-- | returns @True@ if sanitization is specified and the specified attribute
--  is not on the sanitized attribute list.
unsanitaryAttribute (attr, _, _) = do
  st <- getState
  if stateSanitizeHTML st && not (attr `elem` sanitaryAttributes)
    then return True
    else return False

-- | Read blocks until end tag.
blocksTilEnd tag = do
  blocks <- manyTill (block >>~ spaces) (htmlEndTag tag)
  return $ filter (/= Null) blocks

-- | Read inlines until end tag.
inlinesTilEnd tag = manyTill inline (htmlEndTag tag)

-- | Parse blocks between open and close tag.
blocksIn tag = try $ htmlTag tag >> spaces >> blocksTilEnd tag

-- | Parse inlines between open and close tag.
inlinesIn tag = try $ htmlTag tag >> spaces >> inlinesTilEnd tag

-- | Extract type from a tag:  e.g. @br@ from @\<br\>@
extractTagType :: String -> String
extractTagType ('<':rest) = 
  let isSpaceOrSlash c = c `elem` "/ \n\t" in
  map toLower $ takeWhile isAlphaNum $ dropWhile isSpaceOrSlash rest
extractTagType _ = ""

-- | Parse any HTML tag (opening or self-closing) and return text of tag
anyHtmlTag = try $ do
  char '<'
  spaces
  tag <- many1 alphaNum
  attribs <- many htmlAttribute
  spaces
  ender <- option "" (string "/")
  let ender' = if null ender then "" else " /"
  spaces
  char '>'
  let result = "<" ++ tag ++ 
               concatMap (\(_, _, raw) -> (' ':raw)) attribs ++ ender' ++ ">"
  unsanitary <- unsanitaryTag tag
  if unsanitary
     then return $ "<!-- unsafe HTML removed -->"
     else return result

anyHtmlEndTag = try $ do
  char '<'   
  spaces
  char '/'
  spaces
  tag <- many1 alphaNum
  spaces
  char '>'
  let result = "</" ++ tag ++ ">"
  unsanitary <- unsanitaryTag tag
  if unsanitary
     then return $ "<!-- unsafe HTML removed -->"
     else return result 

htmlTag :: String -> GenParser Char ParserState (String, [(String, String)])
htmlTag tag = try $ do
  char '<'
  spaces
  stringAnyCase tag
  attribs <- many htmlAttribute
  spaces
  optional (string "/")
  spaces
  char '>'
  return (tag, (map (\(name, content, raw) -> (name, content)) attribs))

-- parses a quoted html attribute value
quoted quoteChar = do
  result <- between (char quoteChar) (char quoteChar) 
                    (many (noneOf [quoteChar]))
  return (result, [quoteChar])

nullAttribute = ("", "", "") 

htmlAttribute = do
  attr <- htmlRegularAttribute <|> htmlMinimizedAttribute
  unsanitary <- unsanitaryAttribute attr
  if unsanitary
     then return nullAttribute
     else return attr

-- minimized boolean attribute
htmlMinimizedAttribute = try $ do
  many1 space
  name <- many1 (choice [letter, oneOf ".-_:"])
  return (name, name, name)

htmlRegularAttribute = try $ do
  many1 space
  name <- many1 (choice [letter, oneOf ".-_:"])
  spaces
  char '='
  spaces
  (content, quoteStr) <- choice [ (quoted '\''), 
                                  (quoted '"'), 
                                  (do
                                     a <- many (alphaNum <|> (oneOf "-._:"))
                                     return (a,"")) ]
  return (name, content,
          (name ++ "=" ++ quoteStr ++ content ++ quoteStr))

-- | Parse an end tag of type 'tag'
htmlEndTag tag = try $ do
  char '<'   
  spaces
  char '/'
  spaces
  stringAnyCase tag
  spaces
  char '>'
  return $ "</" ++ tag ++ ">"

-- | Returns @True@ if the tag is (or can be) an inline tag.
isInline tag = (extractTagType tag) `elem` inlineHtmlTags

-- | Returns @True@ if the tag is (or can be) a block tag.
isBlock tag = (extractTagType tag) `elem` blockHtmlTags 

anyHtmlBlockTag = try $ do
  tag <- anyHtmlTag <|> anyHtmlEndTag
  if not (isInline tag) then return tag else fail "not a block tag"

anyHtmlInlineTag = try $ do
  tag <- anyHtmlTag <|> anyHtmlEndTag
  if isInline tag then return tag else fail "not an inline tag"

-- | Parses material between script tags.
-- Scripts must be treated differently, because they can contain '<>' etc.
htmlScript = try $ do
  open <- string "<script"
  rest <- manyTill anyChar (htmlEndTag "script")
  st <- getState
  if stateSanitizeHTML st && not ("script" `elem` sanitaryTags)
     then return "<!-- unsafe HTML removed -->"
     else return $ open ++ rest ++ "</script>"

-- | Parses material between style tags.
-- Style tags must be treated differently, because they can contain CSS
htmlStyle = try $ do
  open <- string "<style"
  rest <- manyTill anyChar (htmlEndTag "style")
  st <- getState
  if stateSanitizeHTML st && not ("style" `elem` sanitaryTags)
     then return "<!-- unsafe HTML removed -->"
     else return $ open ++ rest ++ "</style>"

htmlBlockElement = choice [ htmlScript, htmlStyle, htmlComment, xmlDec, definition ]

rawHtmlBlock = try $ do
  body <- htmlBlockElement <|> anyHtmlBlockTag
  state <- getState
  if stateParseRaw state then return (RawHtml body) else return Null

-- We don't want to parse </body> or </html> as raw HTML, since these
-- are handled in parseHtml.
rawHtmlBlock' = do notFollowedBy' (htmlTag "/body" <|> htmlTag "/html")
                   rawHtmlBlock

-- | Parses an HTML comment.
htmlComment = try $ do
  string "<!--"
  comment <- manyTill anyChar (try (string "-->"))
  return $ "<!--" ++ comment ++ "-->"

--
-- parsing documents
--

xmlDec = try $ do
  string "<?"
  rest <- manyTill anyChar (char '>')
  return $ "<?" ++ rest ++ ">"

definition = try $ do
  string "<!"
  rest <- manyTill anyChar (char '>')
  return $ "<!" ++ rest ++ ">"

nonTitleNonHead = try $ do
  notFollowedBy $ (htmlTag "title" >> return ' ') <|> 
                  (htmlEndTag "head" >> return ' ')
  (rawHtmlBlock >> return ' ') <|> anyChar

parseTitle = try $ do
  (tag, _) <- htmlTag "title"
  contents <- inlinesTilEnd tag
  spaces
  return contents

-- parse header and return meta-information (for now, just title)
parseHead = try $ do
  htmlTag "head"
  spaces
  skipMany nonTitleNonHead
  contents <- option [] parseTitle
  skipMany nonTitleNonHead
  htmlEndTag "head"
  return (contents, [], "")

skipHtmlTag tag = optional (htmlTag tag)

-- h1 class="title" representation of title in body
bodyTitle = try $ do
  (tag, attribs) <- htmlTag "h1"  
  cl <- case (extractAttribute "class" attribs) of
          Just "title" -> return ""
          otherwise    -> fail "not title"
  inlinesTilEnd "h1"

parseHtml = do
  sepEndBy (choice [xmlDec, definition, htmlComment]) spaces
  skipHtmlTag "html"
  spaces
  (title, authors, date) <- option ([], [], "") parseHead 
  spaces
  skipHtmlTag "body"
  spaces
  optional bodyTitle  -- skip title in body, because it's represented in meta
  blocks <- parseBlocks
  spaces
  optional (htmlEndTag "body")
  spaces
  optional (htmlEndTag "html" >> many anyChar) -- ignore anything after </html>
  eof
  return $ Pandoc (Meta title authors date) blocks

--
-- parsing blocks
--

parseBlocks = spaces >> sepEndBy block spaces >>= (return . filter (/= Null))

block = choice [ codeBlock
               , header
               , hrule
               , list
               , blockQuote
               , para
               , plain
               , rawHtmlBlock'
               ] <?> "block"

--
-- header blocks
--

header = choice (map headerLevel (enumFromTo 1 5)) <?> "header"

headerLevel n = try $ do
    let level = "h" ++ show n
    (tag, attribs) <- htmlTag level
    contents <- inlinesTilEnd level
    return $ Header n (normalizeSpaces contents)

--
-- hrule block
--

hrule = try  $ do
  (tag, attribs) <- htmlTag "hr"
  state <- getState
  if not (null attribs) && stateParseRaw state
     then unexpected "attributes in hr" -- parse as raw in this case
     else return HorizontalRule

--
-- code blocks
--

-- Note:  HTML tags in code blocks (e.g. for syntax highlighting) are 
-- skipped, because they are not portable to output formats other than HTML.
codeBlock = try $ do
    htmlTag "pre" 
    result <- manyTill 
              (many1 (satisfy (/= '<')) <|> 
               ((anyHtmlTag <|> anyHtmlEndTag) >> return ""))
              (htmlEndTag "pre")
    let result' = concat result
    -- drop leading newline if any
    let result'' = if "\n" `isPrefixOf` result'
                      then drop 1 result'
                      else result'
    -- drop trailing newline if any
    let result''' = if "\n" `isSuffixOf` result''
                       then init result''
                       else result''
    return $ CodeBlock "" $ decodeCharacterReferences result'''

--
-- block quotes
--

blockQuote = try $ htmlTag "blockquote" >> spaces >> 
                   blocksTilEnd "blockquote" >>= (return . BlockQuote)

--
-- list blocks
--

list = choice [ bulletList, orderedList, definitionList ] <?> "list"

orderedList = try $ do
  (_, attribs) <- htmlTag "ol"
  (start, style) <- option (1, DefaultStyle) $
                           do failIfStrict
                              let sta = fromMaybe "1" $ 
                                        lookup "start" attribs
                              let sty = fromMaybe (fromMaybe "" $
                                        lookup "style" attribs) $
                                        lookup "class" attribs
                              let sty' = case sty of
                                          "lower-roman"  -> LowerRoman
                                          "upper-roman"  -> UpperRoman
                                          "lower-alpha"  -> LowerAlpha
                                          "upper-alpha"  -> UpperAlpha
                                          "decimal"      -> Decimal
                                          _              -> DefaultStyle
                              return (read sta, sty')
  spaces
  items <- sepEndBy1 (blocksIn "li") spaces
  htmlEndTag "ol"
  return $ OrderedList (start, style, DefaultDelim) items

bulletList = try $ do
  htmlTag "ul"
  spaces
  items <- sepEndBy1 (blocksIn "li") spaces
  htmlEndTag "ul"
  return $ BulletList items

definitionList = try $ do
  failIfStrict  -- def lists not part of standard markdown
  tag <- htmlTag "dl"
  spaces
  items <- sepEndBy1 definitionListItem spaces
  htmlEndTag "dl"
  return $ DefinitionList items

definitionListItem = try $ do
  terms <- sepEndBy1 (inlinesIn "dt") spaces
  defs <- sepEndBy1 (blocksIn "dd") spaces
  let term = joinWithSep [LineBreak] terms
  return (term, concat defs)

--
-- paragraph block
--

para = try $ htmlTag "p" >> inlinesTilEnd "p" >>= 
             return . Para . normalizeSpaces

-- 
-- plain block
--

plain = many1 inline >>= return . Plain . normalizeSpaces

-- 
-- inline
--

inline = choice [ charRef
                , strong
                , emph
                , superscript
                , subscript
                , strikeout
                , spanStrikeout
                , code
                , str
                , linebreak
                , whitespace
                , link
                , image
                , rawHtmlInline
                ] <?> "inline"

code = try $ do 
  htmlTag "code"
  result <- manyTill anyChar (htmlEndTag "code")
  -- remove internal line breaks, leading and trailing space,
  -- and decode character references
  return $ Code $ decodeCharacterReferences $ removeLeadingTrailingSpace $ 
                  joinWithSep " " $ lines result 

rawHtmlInline = do
  result <- htmlScript <|> htmlStyle <|> htmlComment <|> anyHtmlInlineTag
  state <- getState
  if stateParseRaw state then return (HtmlInline result) else return (Str "")

betweenTags tag = try $ htmlTag tag >> inlinesTilEnd tag >>= 
                        return . normalizeSpaces

emph = (betweenTags "em" <|> betweenTags "i") >>= return . Emph

strong = (betweenTags "b" <|> betweenTags "strong") >>= return . Strong

superscript = failIfStrict >> betweenTags "sup" >>= return . Superscript

subscript = failIfStrict >> betweenTags "sub" >>= return . Subscript

strikeout = failIfStrict >> (betweenTags "s" <|> betweenTags "strike") >>=
            return . Strikeout

spanStrikeout = try $ do
  failIfStrict -- strict markdown has no strikeout, so treat as raw HTML
  (tag, attributes) <- htmlTag "span" 
  result <- case (extractAttribute "class" attributes) of
              Just "strikeout" -> inlinesTilEnd "span"
              _                -> fail "not a strikeout"
  return $ Strikeout result

whitespace = many1 space >> return Space

-- hard line break
linebreak = htmlTag "br" >> optional newline >> return LineBreak

str = many1 (noneOf "<& \t\n") >>= return . Str

--
-- links and images
--

-- extract contents of attribute (attribute names are case-insensitive)
extractAttribute name [] = Nothing
extractAttribute name ((attrName, contents):rest) = 
  let name'     = map toLower name 
      attrName' = map toLower attrName
  in  if attrName' == name'
         then Just (decodeCharacterReferences contents)
         else extractAttribute name rest

link = try $ do
  (tag, attributes) <- htmlTag "a"  
  url <- case (extractAttribute "href" attributes) of
           Just url -> return url
           Nothing  -> fail "no href"
  let title = fromMaybe "" $ extractAttribute "title" attributes
  label <- inlinesTilEnd "a"
  return $ Link (normalizeSpaces label) (url, title)

image = try $ do
  (tag, attributes) <- htmlTag "img" 
  url <- case (extractAttribute "src" attributes) of
           Just url -> return url
           Nothing  -> fail "no src"
  let title = fromMaybe "" $ extractAttribute "title" attributes
  let alt = fromMaybe "" (extractAttribute "alt" attributes)
  return $ Image [Str alt] (url, title)

