-----------------------------------------------------------------------------
-- |
-- Module      :  Text.PrettyPrint.ANSI.Leijen
-- Copyright   :  Daan Leijen (c) 2000, http://www.cs.uu.nl/~daan
--                Max Bolingbroke (c) 2008, http://blog.omega-prime.co.uk
-- License     :  BSD-style (see the file LICENSE)
--
-- Maintainer  :  batterseapower@hotmail.com
-- Stability   :  provisional
-- Portability :  portable
--
-- Pretty print module based on Philip Wadler's \"prettier printer\"
--
-- @
--      \"A prettier printer\"
--      Draft paper, April 1997, revised March 1998.
--      <http://cm.bell-labs.com/cm/cs/who/wadler/papers/prettier/prettier.ps>
-- @
--
-- PPrint is an implementation of the pretty printing combinators
-- described by Philip Wadler (1997). In their bare essence, the
-- combinators of Wadler are not expressive enough to describe some
-- commonly occurring layouts. The PPrint library adds new primitives
-- to describe these layouts and works well in practice.
--
-- The library is based on a single way to concatenate documents,
-- which is associative and has both a left and right unit.  This
-- simple design leads to an efficient and short implementation. The
-- simplicity is reflected in the predictable behaviour of the
-- combinators which make them easy to use in practice.
--
-- A thorough description of the primitive combinators and their
-- implementation can be found in Philip Wadler's paper
-- (1997). Additions and the main differences with his original paper
-- are:
--
-- * The nil document is called empty.
--
-- * The above combinator is called '<$>'. The operator '</>' is used
-- for soft line breaks.
--
-- * There are three new primitives: 'align', 'fill' and
-- 'fillBreak'. These are very useful in practice.
--
-- * Lots of other useful combinators, like 'fillSep' and 'list'.
--
-- * There are two renderers, 'renderPretty' for pretty printing and
-- 'renderCompact' for compact output. The pretty printing algorithm
-- also uses a ribbon-width now for even prettier output.
--
-- * There are two displayers, 'displayS' for strings and 'displayIO' for
-- file based output.
--
-- * There is a 'Pretty' class.
--
-- * The implementation uses optimised representations and strictness
-- annotations.
--
-- Full documentation for the original wl-pprint library available at
-- <http://www.cs.uu.nl/~daan/download/pprint/pprint.html>.
--
-- The library has been extended to allow formatting text for output
-- to ANSI style consoles. New combinators allow:
--
-- * Control of foreground and background color of text
--
-- * The abliity to make parts of the text bold or underlined
--
-- This functionality is, as far as possible, portable across platforms
-- with their varying terminals.  However, one thing to be particularly
-- wary of is that console colors will not be displayed on Windows unless
-- the 'Doc' value is output using the 'putDoc' function or one of it's
-- friends.  Rendering the 'Doc' to a 'String' and then outputing /that/
-- will only work on Unix-style operating systems.
-----------------------------------------------------------
module Text.PrettyPrint.ANSI.Leijen (
   -- * Documents
   Doc, putDoc, hPutDoc,

   -- * Basic combinators
   empty, char, text, (<>), nest, line, linebreak, group, softline,
   softbreak,

   -- * Alignment
   --
   -- The combinators in this section can not be described by Wadler's
   -- original combinators. They align their output relative to the
   -- current output position - in contrast to @nest@ which always
   -- aligns to the current nesting level. This deprives these
   -- combinators from being \`optimal\'. In practice however they
   -- prove to be very useful. The combinators in this section should
   -- be used with care, since they are more expensive than the other
   -- combinators. For example, @align@ shouldn't be used to pretty
   -- print all top-level declarations of a language, but using @hang@
   -- for let expressions is fine.
   align, hang, indent, encloseSep, list, tupled, semiBraces,

   -- * Operators
   (<+>), (<$>), (</>), (<$$>), (<//>),

   -- * List combinators
   hsep, vsep, fillSep, sep, hcat, vcat, fillCat, cat, punctuate,

   -- * Fillers
   fill, fillBreak,

   -- * Bracketing combinators
   enclose, squotes, dquotes, parens, angles, braces, brackets,

   -- * Character documents
   lparen, rparen, langle, rangle, lbrace, rbrace, lbracket, rbracket,
   squote, dquote, semi, colon, comma, space, dot, backslash, equals,
   
   -- * Colorisation combinators
   black, red, green, yellow, blue, magenta, cyan, white,
   dullblack, dullred, dullgreen, dullyellow, dullblue, dullmagenta, dullcyan, dullwhite,
   onblack, onred, ongreen, onyellow, onblue, onmagenta, oncyan, onwhite,
   ondullblack, ondullred, ondullgreen, ondullyellow, ondullblue, ondullmagenta, ondullcyan, ondullwhite,

   -- * Emboldening combinators
   bold, debold,
   
   -- * Underlining combinators
   underline, deunderline,

   -- * Removing formatting
   plain,

   -- * Primitive type documents
   string, int, integer, float, double, rational,

   -- * Pretty class
   Pretty(..),

   -- * Rendering
   SimpleDoc(..), renderPretty, renderCompact, displayS, displayIO

   -- * Undocumented
        , bool

        , column, nesting, width

        ) where

import System.IO (Handle,hPutStr,hPutChar,stdout)

import System.Console.ANSI (Color(..), ColorIntensity(..), ConsoleLayer(..),
                            Underlining(..), ConsoleIntensity(..),
                            SGR(..), hSetSGR, setSGRCode)

import Control.Monad (when)

import Data.String (IsString(..))
import Data.Maybe (isNothing, fromMaybe, catMaybes)
import Data.Monoid (Monoid, mappend, mconcat, mempty)


infixr 5 </>,<//>,<$>,<$$>
infixr 6 <>,<+>


-----------------------------------------------------------
-- list, tupled and semiBraces pretty print a list of
-- documents either horizontally or vertically aligned.
-----------------------------------------------------------


-- | The document @(list xs)@ comma separates the documents @xs@ and
-- encloses them in square brackets. The documents are rendered
-- horizontally if that fits the page. Otherwise they are aligned
-- vertically. All comma separators are put in front of the elements.
list :: [Doc] -> Doc
list            = encloseSep lbracket rbracket comma

-- | The document @(tupled xs)@ comma separates the documents @xs@ and
-- encloses them in parenthesis. The documents are rendered
-- horizontally if that fits the page. Otherwise they are aligned
-- vertically. All comma separators are put in front of the elements.
tupled :: [Doc] -> Doc
tupled          = encloseSep lparen   rparen  comma


-- | The document @(semiBraces xs)@ separates the documents @xs@ with
-- semi colons and encloses them in braces. The documents are rendered
-- horizontally if that fits the page. Otherwise they are aligned
-- vertically. All semi colons are put in front of the elements.
semiBraces :: [Doc] -> Doc
semiBraces      = encloseSep lbrace   rbrace  semi

-- | The document @(encloseSep l r sep xs)@ concatenates the documents
-- @xs@ separated by @sep@ and encloses the resulting document by @l@
-- and @r@. The documents are rendered horizontally if that fits the
-- page. Otherwise they are aligned vertically. All separators are put
-- in front of the elements. For example, the combinator 'list' can be
-- defined with @encloseSep@:
--
-- > list xs = encloseSep lbracket rbracket comma xs
-- > test    = text "list" <+> (list (map int [10,200,3000]))
--
-- Which is layed out with a page width of 20 as:
--
-- @
-- list [10,200,3000]
-- @
--
-- But when the page width is 15, it is layed out as:
--
-- @
-- list [10
--      ,200
--      ,3000]
-- @
encloseSep :: Doc -> Doc -> Doc -> [Doc] -> Doc
encloseSep left right sep ds
    = case ds of
        []  -> left <> right
        [d] -> left <> d <> right
        _   -> align (cat (zipWith (<>) (left : repeat sep) ds) <> right) 


-----------------------------------------------------------
-- punctuate p [d1,d2,...,dn] => [d1 <> p,d2 <> p, ... ,dn]
-----------------------------------------------------------


-- | @(punctuate p xs)@ concatenates all documents in @xs@ with
-- document @p@ except for the last document.
--
-- > someText = map text ["words","in","a","tuple"]
-- > test     = parens (align (cat (punctuate comma someText)))
--
-- This is layed out on a page width of 20 as:
--
-- @
-- (words,in,a,tuple)
-- @
--
-- But when the page width is 15, it is layed out as:
--
-- @
-- (words,
--  in,
--  a,
--  tuple)
-- @
--
-- (If you want put the commas in front of their elements instead of
-- at the end, you should use 'tupled' or, in general, 'encloseSep'.)
punctuate :: Doc -> [Doc] -> [Doc]
punctuate p []      = []
punctuate p [d]     = [d]
punctuate p (d:ds)  = (d <> p) : punctuate p ds


-----------------------------------------------------------
-- high-level combinators
-----------------------------------------------------------


-- | The document @(sep xs)@ concatenates all documents @xs@ either
-- horizontally with @(\<+\>)@, if it fits the page, or vertically with
-- @(\<$\>)@.
--
-- > sep xs  = group (vsep xs)
sep :: [Doc] -> Doc
sep             = group . vsep

-- | The document @(fillSep xs)@ concatenates documents @xs@
-- horizontally with @(\<+\>)@ as long as its fits the page, than
-- inserts a @line@ and continues doing that for all documents in
-- @xs@.
--
-- > fillSep xs  = foldr (\<\/\>) empty xs
fillSep :: [Doc] -> Doc
fillSep         = fold (</>)

-- | The document @(hsep xs)@ concatenates all documents @xs@
-- horizontally with @(\<+\>)@.
hsep :: [Doc] -> Doc
hsep            = fold (<+>)


-- | The document @(vsep xs)@ concatenates all documents @xs@
-- vertically with @(\<$\>)@. If a 'group' undoes the line breaks
-- inserted by @vsep@, all documents are separated with a space.
--
-- > someText = map text (words ("text to lay out"))
-- >
-- > test     = text "some" <+> vsep someText
--
-- This is layed out as:
--
-- @
-- some text
-- to
-- lay
-- out
-- @
--
-- The 'align' combinator can be used to align the documents under
-- their first element
--
-- > test     = text "some" <+> align (vsep someText)
--
-- Which is printed as:
--
-- @
-- some text
--      to
--      lay
--      out
-- @
vsep :: [Doc] -> Doc
vsep            = fold (<$>)

-- | The document @(cat xs)@ concatenates all documents @xs@ either
-- horizontally with @(\<\>)@, if it fits the page, or vertically with
-- @(\<$$\>)@.
--
-- > cat xs  = group (vcat xs)
cat :: [Doc] -> Doc
cat             = group . vcat

-- | The document @(fillCat xs)@ concatenates documents @xs@
-- horizontally with @(\<\>)@ as long as its fits the page, than inserts
-- a @linebreak@ and continues doing that for all documents in @xs@.
--
-- > fillCat xs  = foldr (\<\/\/\>) empty xs
fillCat :: [Doc] -> Doc
fillCat         = fold (<//>)

-- | The document @(hcat xs)@ concatenates all documents @xs@
-- horizontally with @(\<\>)@.
hcat :: [Doc] -> Doc
hcat            = fold (<>)

-- | The document @(vcat xs)@ concatenates all documents @xs@
-- vertically with @(\<$$\>)@. If a 'group' undoes the line breaks
-- inserted by @vcat@, all documents are directly concatenated.
vcat :: [Doc] -> Doc
vcat            = fold (<$$>)

fold f []       = empty
fold f ds       = foldr1 f ds

-- | The document @(x \<\> y)@ concatenates document @x@ and document
-- @y@. It is an associative operation having 'empty' as a left and
-- right unit.  (infixr 6)
(<>) :: Doc -> Doc -> Doc
x <> y          = x `beside` y

-- | The document @(x \<+\> y)@ concatenates document @x@ and @y@ with a
-- @space@ in between.  (infixr 6)
(<+>) :: Doc -> Doc -> Doc
x <+> y         = x <> space <> y

-- | The document @(x \<\/\> y)@ concatenates document @x@ and @y@ with a
-- 'softline' in between. This effectively puts @x@ and @y@ either
-- next to each other (with a @space@ in between) or underneath each
-- other. (infixr 5)
(</>) :: Doc -> Doc -> Doc
x </> y         = x <> softline <> y

-- | The document @(x \<\/\/\> y)@ concatenates document @x@ and @y@ with
-- a 'softbreak' in between. This effectively puts @x@ and @y@ either
-- right next to each other or underneath each other. (infixr 5)
(<//>) :: Doc -> Doc -> Doc
x <//> y        = x <> softbreak <> y

-- | The document @(x \<$\> y)@ concatenates document @x@ and @y@ with a
-- 'line' in between. (infixr 5)
(<$>) :: Doc -> Doc -> Doc
x <$> y         = x <> line <> y

-- | The document @(x \<$$\> y)@ concatenates document @x@ and @y@ with
-- a @linebreak@ in between. (infixr 5)
(<$$>) :: Doc -> Doc -> Doc
x <$$> y        = x <> linebreak <> y

-- | The document @softline@ behaves like 'space' if the resulting
-- output fits the page, otherwise it behaves like 'line'.
--
-- > softline = group line
softline :: Doc
softline        = group line

-- | The document @softbreak@ behaves like 'empty' if the resulting
-- output fits the page, otherwise it behaves like 'line'.
--
-- > softbreak  = group linebreak
softbreak :: Doc
softbreak       = group linebreak

-- | Document @(squotes x)@ encloses document @x@ with single quotes
-- \"'\".
squotes :: Doc -> Doc
squotes         = enclose squote squote

-- | Document @(dquotes x)@ encloses document @x@ with double quotes
-- '\"'.
dquotes :: Doc -> Doc
dquotes         = enclose dquote dquote

-- | Document @(braces x)@ encloses document @x@ in braces, \"{\" and
-- \"}\".
braces :: Doc -> Doc
braces          = enclose lbrace rbrace

-- | Document @(parens x)@ encloses document @x@ in parenthesis, \"(\"
-- and \")\".
parens :: Doc -> Doc
parens          = enclose lparen rparen

-- | Document @(angles x)@ encloses document @x@ in angles, \"\<\" and
-- \"\>\".
angles :: Doc -> Doc
angles          = enclose langle rangle

-- | Document @(brackets x)@ encloses document @x@ in square brackets,
-- \"[\" and \"]\".
brackets :: Doc -> Doc
brackets        = enclose lbracket rbracket

-- | The document @(enclose l r x)@ encloses document @x@ between
-- documents @l@ and @r@ using @(\<\>)@.
--
-- > enclose l r x   = l <> x <> r
enclose :: Doc -> Doc -> Doc -> Doc
enclose l r x   = l <> x <> r

-- | The document @lparen@ contains a left parenthesis, \"(\".
lparen :: Doc
lparen          = char '('
-- | The document @rparen@ contains a right parenthesis, \")\".
rparen :: Doc
rparen          = char ')'
-- | The document @langle@ contains a left angle, \"\<\".
langle :: Doc
langle          = char '<'
-- | The document @rangle@ contains a right angle, \">\".
rangle :: Doc
rangle          = char '>'
-- | The document @lbrace@ contains a left brace, \"{\".
lbrace :: Doc
lbrace          = char '{'
-- | The document @rbrace@ contains a right brace, \"}\".
rbrace :: Doc
rbrace          = char '}'
-- | The document @lbracket@ contains a left square bracket, \"[\".
lbracket :: Doc
lbracket        = char '['
-- | The document @rbracket@ contains a right square bracket, \"]\".
rbracket :: Doc
rbracket        = char ']'


-- | The document @squote@ contains a single quote, \"'\".
squote :: Doc
squote          = char '\''
-- | The document @dquote@ contains a double quote, '\"'.
dquote :: Doc
dquote          = char '"'
-- | The document @semi@ contains a semi colon, \";\".
semi :: Doc
semi            = char ';'
-- | The document @colon@ contains a colon, \":\".
colon :: Doc
colon           = char ':'
-- | The document @comma@ contains a comma, \",\".
comma :: Doc
comma           = char ','
-- | The document @space@ contains a single space, \" \".
--
-- > x <+> y   = x <> space <> y
space :: Doc
space           = char ' '
-- | The document @dot@ contains a single dot, \".\".
dot :: Doc
dot             = char '.'
-- | The document @backslash@ contains a back slash, \"\\\".
backslash :: Doc
backslash       = char '\\'
-- | The document @equals@ contains an equal sign, \"=\".
equals :: Doc
equals          = char '='


-----------------------------------------------------------
-- Combinators for prelude types
-----------------------------------------------------------

-- string is like "text" but replaces '\n' by "line"

-- | The document @(string s)@ concatenates all characters in @s@
-- using @line@ for newline characters and @char@ for all other
-- characters. It is used instead of 'text' whenever the text contains
-- newline characters.
string :: String -> Doc
string ""       = empty
string ('\n':s) = line <> string s
string s        = case (span (/='\n') s) of
                    (xs,ys) -> text xs <> string ys

bool :: Bool -> Doc
bool b          = text (show b)

-- | The document @(int i)@ shows the literal integer @i@ using
-- 'text'.
int :: Int -> Doc
int i           = text (show i)

-- | The document @(integer i)@ shows the literal integer @i@ using
-- 'text'.
integer :: Integer -> Doc
integer i       = text (show i)

-- | The document @(float f)@ shows the literal float @f@ using
-- 'text'.
float :: Float -> Doc
float f         = text (show f)

-- | The document @(double d)@ shows the literal double @d@ using
-- 'text'.
double :: Double -> Doc
double d        = text (show d)

-- | The document @(rational r)@ shows the literal rational @r@ using
-- 'text'.
rational :: Rational -> Doc
rational r      = text (show r)


-----------------------------------------------------------
-- overloading "pretty"
-----------------------------------------------------------

-- | The member @prettyList@ is only used to define the @instance Pretty
-- a => Pretty [a]@. In normal circumstances only the @pretty@ function
-- is used.
class Pretty a where
  pretty        :: a -> Doc
  prettyList    :: [a] -> Doc
  prettyList    = list . map pretty

instance Pretty a => Pretty [a] where
  pretty        = prettyList

instance Pretty Doc where
  pretty        = id

instance Pretty () where
  pretty ()     = text "()"

instance Pretty Bool where
  pretty b      = bool b

instance Pretty Char where
  pretty c      = char c
  prettyList s  = string s

instance Pretty Int where
  pretty i      = int i

instance Pretty Integer where
  pretty i      = integer i

instance Pretty Float where
  pretty f      = float f

instance Pretty Double where
  pretty d      = double d


--instance Pretty Rational where
--  pretty r      = rational r

instance (Pretty a,Pretty b) => Pretty (a,b) where
  pretty (x,y)  = tupled [pretty x, pretty y]

instance (Pretty a,Pretty b,Pretty c) => Pretty (a,b,c) where
  pretty (x,y,z)= tupled [pretty x, pretty y, pretty z]

instance Pretty a => Pretty (Maybe a) where
  pretty Nothing        = empty
  pretty (Just x)       = pretty x



-----------------------------------------------------------
-- semi primitive: fill and fillBreak
-----------------------------------------------------------

-- | The document @(fillBreak i x)@ first renders document @x@. It
-- than appends @space@s until the width is equal to @i@. If the
-- width of @x@ is already larger than @i@, the nesting level is
-- increased by @i@ and a @line@ is appended. When we redefine @ptype@
-- in the previous example to use @fillBreak@, we get a useful
-- variation of the previous output:
--
-- > ptype (name,tp)
-- >        = fillBreak 6 (text name) <+> text "::" <+> text tp
--
-- The output will now be:
--
-- @
-- let empty  :: Doc
--     nest   :: Int -> Doc -> Doc
--     linebreak
--            :: Doc
-- @
fillBreak :: Int -> Doc -> Doc
fillBreak f x   = width x (\w ->
                  if (w > f) then nest f linebreak
                             else text (spaces (f - w)))


-- | The document @(fill i x)@ renders document @x@. It than appends
-- @space@s until the width is equal to @i@. If the width of @x@ is
-- already larger, nothing is appended. This combinator is quite
-- useful in practice to output a list of bindings. The following
-- example demonstrates this.
--
-- > types  = [("empty","Doc")
-- >          ,("nest","Int -> Doc -> Doc")
-- >          ,("linebreak","Doc")]
-- >
-- > ptype (name,tp)
-- >        = fill 6 (text name) <+> text "::" <+> text tp
-- >
-- > test   = text "let" <+> align (vcat (map ptype types))
--
-- Which is layed out as:
--
-- @
-- let empty  :: Doc
--     nest   :: Int -> Doc -> Doc
--     linebreak :: Doc
-- @
fill :: Int -> Doc -> Doc
fill f d        = width d (\w ->
                  if (w >= f) then empty
                              else text (spaces (f - w)))

width :: Doc -> (Int -> Doc) -> Doc
width d f       = column (\k1 -> d <> column (\k2 -> f (k2 - k1)))


-----------------------------------------------------------
-- semi primitive: Alignment and indentation
-----------------------------------------------------------

-- | The document @(indent i x)@ indents document @x@ with @i@ spaces.
--
-- > test  = indent 4 (fillSep (map text
-- >         (words "the indent combinator indents these words !")))
--
-- Which lays out with a page width of 20 as:
--
-- @
--     the indent
--     combinator
--     indents these
--     words !
-- @
indent :: Int -> Doc -> Doc
indent i d      = hang i (text (spaces i) <> d)

-- | The hang combinator implements hanging indentation. The document
-- @(hang i x)@ renders document @x@ with a nesting level set to the
-- current column plus @i@. The following example uses hanging
-- indentation for some text:
--
-- > test  = hang 4 (fillSep (map text
-- >         (words "the hang combinator indents these words !")))
--
-- Which lays out on a page with a width of 20 characters as:
--
-- @
-- the hang combinator
--     indents these
--     words !
-- @
--
-- The @hang@ combinator is implemented as:
--
-- > hang i x  = align (nest i x)
hang :: Int -> Doc -> Doc
hang i d        = align (nest i d)

-- | The document @(align x)@ renders document @x@ with the nesting
-- level set to the current column. It is used for example to
-- implement 'hang'.
--
-- As an example, we will put a document right above another one,
-- regardless of the current nesting level:
--
-- > x $$ y  = align (x <$> y)
--
-- > test    = text "hi" <+> (text "nice" $$ text "world")
--
-- which will be layed out as:
--
-- @
-- hi nice
--    world
-- @
align :: Doc -> Doc
align d         = column (\k ->
                  nesting (\i -> nest (k - i) d))   --nesting might be negative :-)



-----------------------------------------------------------
-- Primitives
-----------------------------------------------------------

-- | The abstract data type @Doc@ represents pretty documents.
--
-- @Doc@ is an instance of the 'Show' class. @(show doc)@ pretty
-- prints document @doc@ with a page width of 100 characters and a
-- ribbon width of 40 characters.
--
-- > show (text "hello" <$> text "world")
--
-- Which would return the string \"hello\\nworld\", i.e.
--
-- @
-- hello
-- world
-- @
data Doc        = Empty
                | Char Char             -- invariant: char is not '\n'
                | Text !Int String      -- invariant: text doesn't contain '\n'
                | Line !Bool            -- True <=> when undone by group, do not insert a space
                | Cat Doc Doc
                | Nest !Int Doc
                | Union Doc Doc         -- invariant: first lines of first doc longer than the first lines of the second doc
                | Column  (Int -> Doc)
                | Nesting (Int -> Doc)
                | Color ConsoleLayer ColorIntensity -- Introduces coloring /around/ the embedded document
                        Color Doc
                | Intensify ConsoleIntensity Doc
                | Italicize Bool Doc
                | Underline Underlining Doc
                | RestoreFormat (Maybe (ColorIntensity, Color))  -- Only used during the rendered phase, to signal a SGR should be issued to restore the terminal formatting.
                                (Maybe (ColorIntensity, Color))  -- These are the colors to revert the current forecolor/backcolor to (i.e. those from before the start of the Color block).
                                (Maybe ConsoleIntensity)         -- Intensity to revert to.
                                (Maybe Bool)                     -- Italicization to revert to.
                                (Maybe Underlining)              -- Underlining to revert to.


-- | The data type @SimpleDoc@ represents rendered documents and is
-- used by the display functions.
--
-- The @Int@ in @SText@ contains the length of the string. The @Int@
-- in @SLine@ contains the indentation for that line. The library
-- provides two default display functions 'displayS' and
-- 'displayIO'. You can provide your own display function by writing a
-- function from a @SimpleDoc@ to your own output format.
data SimpleDoc  = SEmpty
                | SChar Char SimpleDoc
                | SText !Int String SimpleDoc
                | SLine !Int SimpleDoc
                | SSGR [SGR] SimpleDoc


-- MCB: Not in the wl-pprint package that we forked from. I added this when the "pretty" package
-- from base gained a Monoid instance (<http://hackage.haskell.org/trac/ghc/ticket/4378>):
instance Monoid Doc where
    mempty = empty
    mappend = (<>)
    mconcat = hcat

-- MCB: also added when "pretty" got the corresponding instances:
instance IsString Doc where
    fromString = text


-- | The empty document is, indeed, empty. Although @empty@ has no
-- content, it does have a \'height\' of 1 and behaves exactly like
-- @(text \"\")@ (and is therefore not a unit of @\<$\>@).
empty :: Doc
empty           = Empty

-- | The document @(char c)@ contains the literal character @c@. The
-- character shouldn't be a newline (@'\n'@), the function 'line'
-- should be used for line breaks.
char :: Char -> Doc
char '\n'       = line
char c          = Char c

-- | The document @(text s)@ contains the literal string @s@. The
-- string shouldn't contain any newline (@'\n'@) characters. If the
-- string contains newline characters, the function 'string' should be
-- used.
text :: String -> Doc
text ""         = Empty
text s          = Text (length s) s

-- | The @line@ document advances to the next line and indents to the
-- current nesting level. Document @line@ behaves like @(text \" \")@
-- if the line break is undone by 'group'.
line :: Doc
line            = Line False

-- | The @linebreak@ document advances to the next line and indents to
-- the current nesting level. Document @linebreak@ behaves like
-- 'empty' if the line break is undone by 'group'.
linebreak :: Doc
linebreak       = Line True

beside x y      = Cat x y

-- | The document @(nest i x)@ renders document @x@ with the current
-- indentation level increased by i (See also 'hang', 'align' and
-- 'indent').
--
-- > nest 2 (text "hello" <$> text "world") <$> text "!"
--
-- outputs as:
--
-- @
-- hello
--   world
-- !
-- @
nest :: Int -> Doc -> Doc
nest i x        = Nest i x

column, nesting :: (Int -> Doc) -> Doc
column f        = Column f
nesting f       = Nesting f

-- | The @group@ combinator is used to specify alternative
-- layouts. The document @(group x)@ undoes all line breaks in
-- document @x@. The resulting line is added to the current line if
-- that fits the page. Otherwise, the document @x@ is rendered without
-- any changes.
group :: Doc -> Doc
group x         = Union (flatten x) x

flatten :: Doc -> Doc
flatten (Cat x y)        = Cat (flatten x) (flatten y)
flatten (Nest i x)       = Nest i (flatten x)
flatten (Line break)     = if break then Empty else Text 1 " "
flatten (Union x y)      = flatten x
flatten (Column f)       = Column (flatten . f)
flatten (Nesting f)      = Nesting (flatten . f)
flatten (Color l i c x)  = Color l i c (flatten x)
flatten (Intensify i x)  = Intensify i (flatten x)
flatten (Italicize b x)  = Italicize b (flatten x)
flatten (Underline u x)  = Underline u (flatten x)
flatten other            = other                     --Empty,Char,Text,RestoreFormat


-----------------------------------------------------------
-- Colors
-----------------------------------------------------------

-- | Displays a document with the black forecolor
black :: Doc -> Doc
-- | Displays a document with the red forecolor
red :: Doc -> Doc
-- | Displays a document with the green forecolor
green :: Doc -> Doc
-- | Displays a document with the yellow forecolor
yellow :: Doc -> Doc
-- | Displays a document with the blue forecolor
blue :: Doc -> Doc
-- | Displays a document with the magenta forecolor
magenta :: Doc -> Doc
-- | Displays a document with the cyan forecolor
cyan :: Doc -> Doc
-- | Displays a document with the white forecolor
white :: Doc -> Doc
-- | Displays a document with the dull black forecolor
dullblack :: Doc -> Doc
-- | Displays a document with the dull red forecolor
dullred :: Doc -> Doc
-- | Displays a document with the dull green forecolor
dullgreen :: Doc -> Doc
-- | Displays a document with the dull yellow forecolor
dullyellow :: Doc -> Doc
-- | Displays a document with the dull blue forecolor
dullblue :: Doc -> Doc
-- | Displays a document with the dull magenta forecolor
dullmagenta :: Doc -> Doc
-- | Displays a document with the dull cyan forecolor
dullcyan :: Doc -> Doc
-- | Displays a document with the dull white forecolor
dullwhite :: Doc -> Doc
(black, dullblack)     = colorFunctions Black
(red, dullred)         = colorFunctions Red
(green, dullgreen)     = colorFunctions Green
(yellow, dullyellow)   = colorFunctions Yellow
(blue, dullblue)       = colorFunctions Blue
(magenta, dullmagenta) = colorFunctions Magenta
(cyan, dullcyan)       = colorFunctions Cyan
(white, dullwhite)     = colorFunctions White

-- | Displays a document with a forecolor given in the first parameter
color :: Color -> Doc -> Doc
-- | Displays a document with a dull forecolor given in the first parameter
dullcolor :: Color -> Doc -> Doc
color     = Color Foreground Vivid
dullcolor = Color Foreground Dull

colorFunctions :: Color -> (Doc -> Doc, Doc -> Doc)
colorFunctions what = (color what, dullcolor what)

-- | Displays a document with the black backcolor
onblack :: Doc -> Doc
-- | Displays a document with the red backcolor
onred :: Doc -> Doc
-- | Displays a document with the green backcolor
ongreen :: Doc -> Doc
-- | Displays a document with the yellow backcolor
onyellow :: Doc -> Doc
-- | Displays a document with the blue backcolor
onblue :: Doc -> Doc
-- | Displays a document with the magenta backcolor
onmagenta :: Doc -> Doc
-- | Displays a document with the cyan backcolor
oncyan :: Doc -> Doc
-- | Displays a document with the white backcolor
onwhite :: Doc -> Doc
-- | Displays a document with the dull block backcolor
ondullblack :: Doc -> Doc
-- | Displays a document with the dull red backcolor
ondullred :: Doc -> Doc
-- | Displays a document with the dull green backcolor
ondullgreen :: Doc -> Doc
-- | Displays a document with the dull yellow backcolor
ondullyellow :: Doc -> Doc
-- | Displays a document with the dull blue backcolor
ondullblue :: Doc -> Doc
-- | Displays a document with the dull magenta backcolor
ondullmagenta :: Doc -> Doc
-- | Displays a document with the dull cyan backcolor
ondullcyan :: Doc -> Doc
-- | Displays a document with the dull white backcolor
ondullwhite :: Doc -> Doc
(onblack, ondullblack)     = oncolorFunctions Black
(onred, ondullred)         = oncolorFunctions Red
(ongreen, ondullgreen)     = oncolorFunctions Green
(onyellow, ondullyellow)   = oncolorFunctions Yellow
(onblue, ondullblue)       = oncolorFunctions Blue
(onmagenta, ondullmagenta) = oncolorFunctions Magenta
(oncyan, ondullcyan)       = oncolorFunctions Cyan
(onwhite, ondullwhite)     = oncolorFunctions White

-- | Displays a document with a backcolor given in the first parameter
oncolor :: Color -> Doc -> Doc
-- | Displays a document with a dull backcolor given in the first parameter
ondullcolor :: Color -> Doc -> Doc
oncolor     = Color Background Vivid
ondullcolor = Color Background Dull

oncolorFunctions :: Color -> (Doc -> Doc, Doc -> Doc)
oncolorFunctions what = (oncolor what, ondullcolor what)


-----------------------------------------------------------
-- Console Intensity
-----------------------------------------------------------

-- | Displays a document in a heavier font weight
bold :: Doc -> Doc
bold = Intensify BoldIntensity

-- | Displays a document in the normal font weight
debold :: Doc -> Doc
debold = Intensify NormalIntensity

-- NB: I don't support FaintIntensity here because it is not widely supported by terminals.


-----------------------------------------------------------
-- Italicization
-----------------------------------------------------------

{-

I'm in two minds about providing these functions, since italicization is so rarely implemented.
It is especially bad because "italicization" may cause the meaning of colors to flip, which will
look a bit weird, to say the least...


-- | Displays a document in italics. This is not widely supported, and it's use is not recommended
italicize :: Doc -> Doc
italicize = Italicize True

-- | Displays a document with no italics
deitalicize :: Doc -> Doc
deitalicize = Italicize False

-}

-----------------------------------------------------------
-- Underlining
-----------------------------------------------------------

-- | Displays a document with underlining
underline :: Doc -> Doc
underline = Underline SingleUnderline

-- | Displays a document with no underlining
deunderline :: Doc -> Doc
deunderline = Underline NoUnderline

-- NB: I don't support DoubleUnderline here because it is not widely supported by terminals.

-----------------------------------------------------------
-- Removing formatting
-----------------------------------------------------------

-- | Removes all colorisation, emboldening and underlining from a document
plain :: Doc -> Doc
plain e@Empty         = e
plain c@(Char _)      = c
plain t@(Text _ _)    = t
plain l@(Line _)      = l
plain (Cat x y)       = Cat (plain x) (plain y)
plain (Nest i x)      = Nest i (plain x)
plain (Union x y)     = Union (plain x) (plain y)
plain (Column f)      = Column (plain . f)
plain (Nesting f)     = Nesting (plain . f)
plain (Color _ _ _ x) = plain x
plain (Intensify _ x) = plain x
plain (Italicize _ x) = plain x
plain (Underline _ x) = plain x
plain (RestoreFormat _ _ _ _ _) = Empty

-----------------------------------------------------------
-- Renderers
-----------------------------------------------------------

-----------------------------------------------------------
-- renderPretty: the default pretty printing algorithm
-----------------------------------------------------------

-- list of indentation/document pairs; saves an indirection over [(Int,Doc)]
data Docs   = Nil
            | Cons !Int Doc Docs


-- | This is the default pretty printer which is used by 'show',
-- 'putDoc' and 'hPutDoc'. @(renderPretty ribbonfrac width x)@ renders
-- document @x@ with a page width of @width@ and a ribbon width of
-- @(ribbonfrac * width)@ characters. The ribbon width is the maximal
-- amount of non-indentation characters on a line. The parameter
-- @ribbonfrac@ should be between @0.0@ and @1.0@. If it is lower or
-- higher, the ribbon width will be 0 or @width@ respectively.
renderPretty :: Float -> Int -> Doc -> SimpleDoc
renderPretty rfrac w x
    -- I used to do a @SSGR [Reset]@ here, but if you do that it will result
    -- in any rendered @Doc@ containing at least some ANSI control codes. This
    -- may be undesirable if you want to render to non-ANSI devices by simply
    -- not making use of the ANSI color combinators I provide.
    --
    -- What I "really" want to do here is do an initial Reset iff there is some
    -- ANSI color within the Doc, but that's a bit fiddly. I'll fix it if someone
    -- complains!
    = best 0 0 Nothing Nothing Nothing Nothing Nothing (Cons 0 x Nil)
    where
      -- r :: the ribbon width in characters
      r  = max 0 (min w (round (fromIntegral w * rfrac)))

      -- best :: n = indentation of current line
      --         k = current column
      --        (ie. (k >= n) && (k - n == count of inserted characters)
      best n k mb_fc mb_bc mb_in mb_it mb_un Nil = SEmpty
      best n k mb_fc mb_bc mb_in mb_it mb_un (Cons i d ds)
        = case d of
            Empty         -> best_typical n k ds
            Char c        -> let k' = k+1 in seq k' (SChar c (best_typical n k' ds))
            Text l s      -> let k' = k+l in seq k' (SText l s (best_typical n k' ds))
            Line _        -> SLine i (best_typical i i ds)
            Cat x y       -> best_typical n k (Cons i x (Cons i y ds))
            Nest j x      -> let i' = i+j in seq i' (best_typical n k (Cons i' x ds))
            Union x y     -> nicest n k (best_typical n k (Cons i x ds))
                                        (best_typical n k (Cons i y ds))
            Column f      -> best_typical n k (Cons i (f k) ds)
            Nesting f     -> best_typical n k (Cons i (f i) ds)
            Color l t c x -> SSGR [SetColor l t c] (best n k mb_fc' mb_bc' mb_in mb_it mb_un (Cons i x ds_restore))
              where
                mb_fc' = case l of { Background -> mb_fc; Foreground -> Just (t, c) }
                mb_bc' = case l of { Background -> Just (t, c); Foreground -> mb_bc }
            Intensify t x -> SSGR [SetConsoleIntensity t] (best n k mb_fc mb_bc (Just t) mb_it mb_un (Cons i x ds_restore))
            Italicize t x -> SSGR [SetItalicized t] (best n k mb_fc mb_bc mb_in (Just t) mb_un (Cons i x ds_restore))
            Underline u x -> SSGR [SetUnderlining u] (best n k mb_fc mb_bc mb_in mb_it (Just u) (Cons i x ds_restore))
            RestoreFormat mb_fc' mb_bc' mb_in' mb_it' mb_un' -> SSGR sgrs (best n k mb_fc' mb_bc' mb_in' mb_it' mb_un' ds)
              where
                -- We need to be able to restore the entire SGR state, hence we carry around what we believe
                -- that state should be in all the arguments to this function. Note that in some cases we could
                -- avoid the Reset of the entire state, but not in general.
                sgrs = Reset : catMaybes [
                    fmap (uncurry (SetColor Foreground)) mb_fc',
                    fmap (uncurry (SetColor Background)) mb_bc',
                    fmap SetConsoleIntensity mb_in',
                    fmap SetItalicized mb_it',
                    fmap SetUnderlining mb_un'
                  ]
        where
          best_typical n' k' ds' = best n' k' mb_fc mb_bc mb_in mb_it mb_un ds'
          ds_restore = Cons i (RestoreFormat mb_fc mb_bc mb_in mb_it mb_un) ds

      --nicest :: r = ribbon width, w = page width,
      --          n = indentation of current line, k = current column
      --          x and y, the (simple) documents to chose from.
      --          precondition: first lines of x are longer than the first lines of y.
      nicest n k x y    | fits width x  = x
                        | otherwise     = y
                        where
                          width = min (w - k) (r - k + n)

fits w x        | w < 0     = False
fits w SEmpty               = True
fits w (SChar c x)          = fits (w - 1) x
fits w (SText l s x)        = fits (w - l) x
fits w (SLine i x)          = True
fits w (SSGR s x)           = fits w x


-----------------------------------------------------------
-- renderCompact: renders documents without indentation
--  fast and fewer characters output, good for machines
-----------------------------------------------------------


-- | @(renderCompact x)@ renders document @x@ without adding any
-- indentation. Since no \'pretty\' printing is involved, this
-- renderer is very fast. The resulting output contains fewer
-- characters than a pretty printed version and can be used for output
-- that is read by other programs.
--
-- This rendering function does not add any colorisation information.
renderCompact :: Doc -> SimpleDoc
renderCompact x
    = scan 0 [x]
    where
      scan k []     = SEmpty
      scan k (d:ds) = case d of
                        Empty                   -> scan k ds
                        Char c                  -> let k' = k+1 in seq k' (SChar c (scan k' ds))
                        Text l s                -> let k' = k+l in seq k' (SText l s (scan k' ds))
                        Line _                  -> SLine 0 (scan 0 ds)
                        Cat x y                 -> scan k (x:y:ds)
                        Nest j x                -> scan k (x:ds)
                        Union x y               -> scan k (y:ds)
                        Column f                -> scan k (f k:ds)
                        Nesting f               -> scan k (f 0:ds)
                        Color _ _ _ x           -> scan k (x:ds)
                        Intensify _ x           -> scan k (x:ds)
                        Italicize _ x           -> scan k (x:ds)
                        Underline _ x           -> scan k (x:ds)
                        RestoreFormat _ _ _ _ _ -> scan k ds



-----------------------------------------------------------
-- Displayers:  displayS and displayIO
-----------------------------------------------------------


-- | @(displayS simpleDoc)@ takes the output @simpleDoc@ from a
-- rendering function and transforms it to a 'ShowS' type (for use in
-- the 'Show' class).
--
-- > showWidth :: Int -> Doc -> String
-- > showWidth w x   = displayS (renderPretty 0.4 w x) ""
--
-- ANSI color information will be discarded by this function unless
-- you are running on a Unix-like operating system. This is due to
-- a technical limitation in Windows ANSI support.
displayS :: SimpleDoc -> ShowS
displayS SEmpty             = id
displayS (SChar c x)        = showChar c . displayS x
displayS (SText l s x)      = showString s . displayS x
displayS (SLine i x)        = showString ('\n':indentation i) . displayS x
displayS (SSGR s x)         = showString (setSGRCode s) . displayS x


-- | @(displayIO handle simpleDoc)@ writes @simpleDoc@ to the file
-- handle @handle@. This function is used for example by 'hPutDoc':
--
-- > hPutDoc handle doc  = displayIO handle (renderPretty 0.4 100 doc)
--
-- Any ANSI colorisation in @simpleDoc@ will be output.
displayIO :: Handle -> SimpleDoc -> IO ()
displayIO handle simpleDoc
    = display simpleDoc
    where
      display SEmpty         = return ()
      display (SChar c x)    = do{ hPutChar handle c; display x}
      display (SText l s x)  = do{ hPutStr handle s; display x}
      display (SLine i x)    = do{ hPutStr handle ('\n':indentation i); display x}
      display (SSGR s x)     = do{ hSetSGR handle s; display x}

-----------------------------------------------------------
-- default pretty printers: show, putDoc and hPutDoc
-----------------------------------------------------------
instance Show Doc where
  showsPrec d doc       = displayS (renderPretty 0.4 80 doc)

-- | The action @(putDoc doc)@ pretty prints document @doc@ to the
-- standard output, with a page width of 100 characters and a ribbon
-- width of 40 characters.
--
-- > main :: IO ()
-- > main = do{ putDoc (text "hello" <+> text "world") }
--
-- Which would output
--
-- @
-- hello world
-- @
--
-- Any ANSI colorisation in @doc@ will be output.
putDoc :: Doc -> IO ()
putDoc doc              = hPutDoc stdout doc

-- | @(hPutDoc handle doc)@ pretty prints document @doc@ to the file
-- handle @handle@ with a page width of 100 characters and a ribbon
-- width of 40 characters.
--
-- > main = do{ handle <- openFile "MyFile" WriteMode
-- >          ; hPutDoc handle (vcat (map text
-- >                            ["vertical","text"]))
-- >          ; hClose handle
-- >          }
--
-- Any ANSI colorisation in @doc@ will be output.
hPutDoc :: Handle -> Doc -> IO ()
hPutDoc handle doc  = displayIO handle (renderPretty 0.4 80 doc)



-----------------------------------------------------------
-- insert spaces
-- "indentation" used to insert tabs but tabs seem to cause
-- more trouble than they solve :-)
-----------------------------------------------------------
spaces n        | n <= 0    = ""
                | otherwise = replicate n ' '

indentation n   = spaces n

--indentation n   | n >= 8    = '\t' : indentation (n-8)
--                | otherwise = spaces n

--  LocalWords:  PPrint combinators Wadler Wadler's encloseSep
