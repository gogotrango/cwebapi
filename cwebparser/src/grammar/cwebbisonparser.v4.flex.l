/* cwebbisonparser.v4.flex.l */

/*
MIT License

Copyright (c) 2021 Zartaj Majeed

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
*/


 // flex directives

 // turn on warnings
%option warn

 // always generate 8bit lexer
%option 8bit

 // C++ lexer class
%option c++

 // custom C++ lexer classname
%option yyclass="CWebLexer"

 // custom prefix to turn yyFlexLexer into CWebFlexLexer
%option prefix="CWeb"

%option debug

 // disable echo from default rule for unmatched input, gives flex scanner jammed error if default rule runs for any unmatched input
%option nodefault

 // noninteractive lexer has better performance, use with -Cfe
%option never-interactive

%option noyywrap

 // disable various options for interactive lexer
 // yyless is better than unput, also consider lookahead in pattern alternative to yyless
%option nounput noinput batch

 // for yy_push_state to use states stack
%option stack

 // lexer states start conditions
 // these major tokenization modes are set by parser via lexical feedback

 // Mode::limbo, special characters: @ for control code, \n for line count
%x LIMBO
 // Mode::tex, special characters: @ for control code, \n for line count, | for inner c context
%x TEX
 // Mode::middle, special characters: @ for control code, \n for line count
%x MIDDLE
 // Mode::c, special characters: @ for control code, \n for line count, / for comment
%x C
 // Mode::inner_c, special characters: @ for control code, \n for line count, / for comment, | for inner c delimiter
%x INNER_C
 // Mode::tex, SubMode::inner_c, special characters: @ for control code, \n for line count, / for comment
%x INNER_C_TEX
 // Mode::tex, SubMode::inner_c, special characters: @ for control code, \n for line count, / for comment
%x INNER_C_COMMENT
%x RESTRICTED_TEX

 // @i include file directive
%x INCLUDE_FILE_START
%x INCLUDE_FILE_SKIP_TO_EOL

 // various control codes
%x CONTROL_TEXT_START

%x MACRO_BEGIN MACRO_PARAMS MACRO_PARAMS_SEPARATOR MACRO_BODY

 // main control code scanning state
%x CONTROL

%x STARRED_TEX_BEGIN
%x NAMED_SECTION_BEGIN
%x FORMAT_DEF_BEGIN
%x FILE_OUTPUT_C_SECTION_BEGIN

 // comment tokenization states
%x C_COMMENT
%x CPLUSPLUS_COMMENT

 // c string tokenization states
%x C_STRING_CHARS
%x CLOSE_QUOTE

 // c++ raw string tokenization states
%x CPLUSPLUS_RAWSTRING_CHARS

 // regex aliases
identifier [A-z_][A-z_0-9]*

 // top of generated .cpp file
%{

/*
MIT License

Copyright (c) 2021 Zartaj Majeed

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
*/

#include <iostream>
#include <istream>
#include <string>
#include <utility>
#include <charconv>

#include <fmt/format.h>

// bison generated header with C++ namespace and token definitions
#include "bisonparser/v4/cwebbisonparser.v4.bison.h"

// the lexer class derived from flex c++ lexer
#include "flexlexer/v4/cweblexer.v4.h"

#undef YY_DECL
// this is for yylex implementation in .cpp generated by flex
#define YY_DECL CWebBisonParser::symbol_type CWebLexer::yylex(BisonParserState& parserState)

// override default yyterminate that just returns YY_NULL or 0 which works without locations but gives compile error when location is enabled because symbol_type no longer has single int constructor that can act as implicit converter
#define yyterminate() return symbol_type(YY_NULL, publicState.loc)

using namespace std;
using namespace fmt;

using namespace cweb::v4;

using Token = CWebBisonParser::token::token_kind_type;
// needed for yyterminate
using symbol_type = CWebBisonParser::symbol_type;
using Mode = BisonParserState::Mode;
using IncludeFileState = BisonParserState::IncludeFileState;

// flex start conditions lexer states definitions appear below in generated .cpp
%}

 // flex rules
%%
 // code must be indented, comments after first rule must be c comments not c++ comments

  auto& parserLocation = parserState.loc;

  if(tokenIsPending) {
    if(debug() != 0)
      print("CWebLexer.{}.{}: return pending token \"{}\"\n", __func__, __LINE__, pendingToken.name());
    tokenIsPending = false;
    return pendingToken;
  }

  if(parserState.includeFileState == IncludeFileState::open) {
    includeFileStart(parserState.includeFile);
    parserState.includeFileState = IncludeFileState::reading;
  }

 // local temporary variables to fill and pass info between actions
  Token token;
  StarredTexSection starredTexSection;
  IncludeFile includeFile;
  MacroName macro;
  string tmpString;
  string freeTextSave;
  vector<string> tmpStringArray;
  FormatDefinition formatDef;
  IndexEntry indexEntry;
  NamedSection namedSection;

  bool escapeMacroNewlines = config.escapeMacroNewlines;
  bool haveUnescapedNewline = false;

  parserLocation.step();

 // set lexer state as parser says
  setLexerState(parserState);

 /* limbo source text free of control codes and newlines */
 /* @ for control code, \n to count lines */
<LIMBO,MIDDLE>[^@\n]* {
 parserLocation.columns(yyleng);
 tmpString += yytext;
}

 /* tex line free of control codes and inner c blocks */
 /* @ for control code, \n to count lines, | for inner c context */
<TEX>[^@|\n]* {
  parserLocation.columns(yyleng);
  tmpString += yytext;
}

 /* C source text line free of control codes, comments, strings */
 /* @ for control code, / for potential comment, \n to count lines, \" for strings */
<C>[^@/\n"]* {
  parserLocation.columns(yyleng);
  tmpString += yytext;
}

 /* inner c is just like c except | is special closing delimiter and comments not allowed */
 /* C source text line free of control codes and comments */
 /* @ for control code, / for potential comment, \n to count lines */
<INNER_C>[^@/|\n]* {
  parserLocation.columns(yyleng);
  tmpString += yytext;
}

 /* check for 2-character slash sequences */
<C,INNER_C,MACRO_BODY>{

 /* opening delimiter of c comment */
  "/*" {
    parserLocation.columns(yyleng);
    setPendingToken(CWebBisonParser::make_C_COMMENT_BEGIN(yytext, parserLocation));
    return CWebBisonParser::make_FREE_TEXT(tmpString, parserLocation);
  }

 /* opening delimiter of c++ comment */
  "//" {
    parserLocation.columns(yyleng);
    setPendingToken(CWebBisonParser::make_CPLUSPLUS_COMMENT_BEGIN(yytext, parserLocation));
    return CWebBisonParser::make_FREE_TEXT(tmpString, parserLocation);
  }

 /* any other special character after slash has its own rule  */
  "/" {
    parserLocation.columns(yyleng);
    tmpString += yytext;
  }

 /* quoted string starts */
  \" {
    parserLocation.columns(yyleng);
    setPendingToken(CWebBisonParser::make_DOUBLE_QUOTE(yytext, parserLocation));
    return CWebBisonParser::make_FREE_TEXT(tmpString, parserLocation);
  }

}

 /* pipe opens inner c in tex and closes inner c */
<TEX,INNER_C>"|" {
  parserLocation.columns(yyleng);
  setPendingToken(CWebBisonParser::make_INNER_C_CONTEXT_DELIM(yytext, parserLocation));
  return CWebBisonParser::make_FREE_TEXT(tmpString, parserLocation);
}

 /* count lines */
<LIMBO,TEX,MIDDLE,C,INNER_C,C_COMMENT>\n+ {
 parserLocation.lines(yyleng);
 tmpString += yytext;
}

 /* control code always passes through here */
<LIMBO,TEX,MIDDLE,C,C_COMMENT,CPLUSPLUS_COMMENT,MACRO_BODY>@ {
  BEGIN(CONTROL);
  parserLocation.columns(yyleng);
  freeTextSave.swap(tmpString);
  tmpString = yytext;
}

 /************************************************************************/
 /* control text codes */
 /* @^ text @>, @^Graham, Ronald Lewis@> */
 /* @^, @., @:, @t, @=, @q, @! */
<CONTROL>(?x: (^ | "." | : | t | = | q | !) ) {
  BEGIN(CONTROL_TEXT_START);
  parserLocation.columns(yyleng);
  tmpString += yytext;
  auto codeChar = yytext[0];
  switch(codeChar) {
    case '^': token = Token::INDEX_ENTRY; break;
    case '.': token = Token::INDEX_TYPEWRITER; break;
    case ':': token = Token::INDEX_TEX9; break;
    case 't': token = Token::HBOX_TEXT; break;
    case '=': token = Token::VERBATIM_TEXT; break;
    case 'q': token = Token::COMMENT_TEXT; break;
    case '!': token = Token::INDEX_UNDERLINE; break;
  }
}

 /* generic rules for control text for different tokens */
<CONTROL_TEXT_START>{

  /* replace @@ with @ */
  @@ {
    tmpString += "@";
    indexEntry.entry += "@";
    parserLocation.columns(yyleng);
  }

  /* control text is complete, return symbol */
  @> {
    tmpString += yytext;
    indexEntry.text.assign(tmpString);
    parserLocation.columns(yyleng);
    setPendingToken(symbol_type(token, indexEntry, parserLocation));
    return CWebBisonParser::make_FREE_TEXT(freeTextSave, parserLocation);
  }

 /* munch max input clean of control codes */
  [^@\n]+ {
    tmpString += yytext;
    indexEntry.entry += yytext;
    parserLocation.columns(yyleng);
  }

 /* may error here for unallowed control codes */
  @[^@\n]+ {
    tmpString += yytext;
    indexEntry.entry += yytext;
    parserLocation.columns(yyleng);
  }

  \n {
    tmpString += yytext;
    parserLocation.lines();
    throw CWebBisonParser::syntax_error(parserLocation, "control text cannot have newline \"" + tmpString + string(tmpString) + "\"");
  }

}
 /************************************************************************/

 /************************************************************************/
 /* generic control code handler */
<CONTROL>. {

 parserLocation.columns(yyleng);
 tmpString += yytext;
 auto codeChar = yytext[0];
 BEGIN(0);

 switch(codeChar) {
   case 'c': // @c
   case 'p': // @p
     if(freeTextSave.empty()) {
       return CWebBisonParser::make_UNNAMED_PROGRAM_SECTION_BEGIN(tmpString, parserLocation);
     }
     setPendingToken(CWebBisonParser::make_UNNAMED_PROGRAM_SECTION_BEGIN(tmpString, parserLocation));
     return CWebBisonParser::make_FREE_TEXT(freeTextSave, parserLocation);

   case 'd': // @d
     BEGIN(MACRO_BEGIN);
     if(freeTextSave.empty()) {
       return CWebBisonParser::make_MACRO_BEGIN(tmpString, parserLocation);
     }
     setPendingToken(CWebBisonParser::make_MACRO_BEGIN(tmpString, parserLocation));
     return CWebBisonParser::make_FREE_TEXT(freeTextSave, parserLocation);

   case 'f': // @f
     BEGIN(FORMAT_DEF_BEGIN);
     formatDef.text = tmpString;
     formatDef.suppress = false;
     break;

   case ' ': // @space
     if(freeTextSave.empty()) {
       return CWebBisonParser::make_UNSTARRED_TEX_BEGIN(tmpString, parserLocation);
     }
     setPendingToken(CWebBisonParser::make_UNSTARRED_TEX_BEGIN(tmpString, parserLocation));
     return CWebBisonParser::make_FREE_TEXT(freeTextSave, parserLocation);

   case '*': // @*
     BEGIN(STARRED_TEX_BEGIN);
     starredTexSection.text = tmpString;
     break;

   case 's': // @s
     BEGIN(FORMAT_DEF_BEGIN);
     formatDef.text = tmpString;
     formatDef.suppress = true;
     break;

   case '<': // @<
     BEGIN(NAMED_SECTION_BEGIN);
     namedSection.text = tmpString;
     break;

   case ',': // @,
     if(freeTextSave.empty()) {
       return CWebBisonParser::make_THIN_SPACE(tmpString, parserLocation);
     }
     setPendingToken(CWebBisonParser::make_THIN_SPACE(tmpString, parserLocation));
     return CWebBisonParser::make_FREE_TEXT(freeTextSave, parserLocation);

   case '/': // @/
     if(freeTextSave.empty()) {
       return CWebBisonParser::make_LINEBREAK(tmpString, parserLocation);
     }
     setPendingToken(CWebBisonParser::make_LINEBREAK(tmpString, parserLocation));
     return CWebBisonParser::make_FREE_TEXT(freeTextSave, parserLocation);

   case '|': // @|
     if(freeTextSave.empty()) {
       return CWebBisonParser::make_OPTIONAL_LINEBREAK(tmpString, parserLocation);
     }
     setPendingToken(CWebBisonParser::make_OPTIONAL_LINEBREAK(tmpString, parserLocation));
     return CWebBisonParser::make_FREE_TEXT(freeTextSave, parserLocation);

   case '#': // @#
     if(freeTextSave.empty()) {
       return CWebBisonParser::make_FORCE_LINEBREAK(tmpString, parserLocation);
     }
     setPendingToken(CWebBisonParser::make_FORCE_LINEBREAK(tmpString, parserLocation));
     return CWebBisonParser::make_FREE_TEXT(freeTextSave, parserLocation);

   case '+': // @+
     if(freeTextSave.empty()) {
       return CWebBisonParser::make_CANCEL_LINEBREAK(tmpString, parserLocation);
     }
     setPendingToken(CWebBisonParser::make_CANCEL_LINEBREAK(tmpString, parserLocation));
     return CWebBisonParser::make_FREE_TEXT(freeTextSave, parserLocation);

   case ';': // @;
     if(freeTextSave.empty()) {
       return CWebBisonParser::make_INVISIBLE_SEMICOLON(tmpString, parserLocation);
     }
     setPendingToken(CWebBisonParser::make_INVISIBLE_SEMICOLON(tmpString, parserLocation));
     return CWebBisonParser::make_FREE_TEXT(freeTextSave, parserLocation);

   case '[': // @[
     if(freeTextSave.empty()) {
       return CWebBisonParser::make_FORMAT_C_EXPRESSION_BEGIN(tmpString, parserLocation);
     }
     setPendingToken(CWebBisonParser::make_FORMAT_C_EXPRESSION_BEGIN(tmpString, parserLocation));
     return CWebBisonParser::make_FREE_TEXT(freeTextSave, parserLocation);

   case ']': // @]
     if(freeTextSave.empty()) {
       return CWebBisonParser::make_FORMAT_C_EXPRESSION_END(tmpString, parserLocation);
     }
     setPendingToken(CWebBisonParser::make_FORMAT_C_EXPRESSION_END(tmpString, parserLocation));
     return CWebBisonParser::make_FREE_TEXT(freeTextSave, parserLocation);

   case '(': // @(
     BEGIN(FILE_OUTPUT_C_SECTION_BEGIN);
     break;

   case 'h': // @h
     if(freeTextSave.empty()) {
       return CWebBisonParser::make_EMIT_MACROS_HERE(tmpString, parserLocation);
     }
     setPendingToken(CWebBisonParser::make_EMIT_MACROS_HERE(tmpString, parserLocation));
     return CWebBisonParser::make_FREE_TEXT(freeTextSave, parserLocation);

   case 'i': // @i
     BEGIN(INCLUDE_FILE_START);
     includeFile.text = tmpString;
     break;
 }

}
 /************************************************************************/

 /* @* title., "@* Introduction." */
<STARRED_TEX_BEGIN>[^.]*\.  {
  parserLocation.columns(yyleng);
  starredTexSection.text += yytext;
  if(freeTextSave.empty()) {
    return CWebBisonParser::make_STARRED_TEX_BEGIN(starredTexSection, parserLocation);
  }
  setPendingToken(CWebBisonParser::make_STARRED_TEX_BEGIN(starredTexSection, parserLocation));
  return CWebBisonParser::make_FREE_TEXT(freeTextSave, parserLocation);
}

<NAMED_SECTION_BEGIN>[^@]+@>"+"?= {
  namedSection.text += yytext;
  namedSection.name.assign(yytext, yyleng - 3);
  namedSection.isContinuation = yytext[yyleng - 2] == '+';
  namedSection.isPrefix = namedSection.name.ends_with("...");
  if(freeTextSave.empty()) {
    return CWebBisonParser::make_NAMED_SECTION_BEGIN(namedSection, parserLocation);
  }
  setPendingToken(CWebBisonParser::make_NAMED_SECTION_BEGIN(namedSection, parserLocation));
  return CWebBisonParser::make_FREE_TEXT(freeTextSave, parserLocation);
}

<NAMED_SECTION_BEGIN>[^@]+@> {
  namedSection.text += yytext;
  namedSection.name.assign(yytext, yyleng - 2);
  namedSection.isPrefix = namedSection.name.ends_with("...");
  if(freeTextSave.empty()) {
    return CWebBisonParser::make_SECTION_NAME(namedSection, parserLocation);
  }
  setPendingToken(CWebBisonParser::make_SECTION_NAME(namedSection, parserLocation));
  return CWebBisonParser::make_FREE_TEXT(freeTextSave, parserLocation);
}

<FILE_OUTPUT_C_SECTION_BEGIN>.*@> {
  tmpString.append(yytext, yyleng - 2);
  return CWebBisonParser::make_FILE_OUTPUT_C_SECTION_BEGIN(tmpString, parserLocation);
}

<FORMAT_DEF_BEGIN>" "+ formatDef.text += yytext;

<FORMAT_DEF_BEGIN>{identifier} {
  formatDef.text += yytext;
  if(formatDef.left.empty()) {
    formatDef.left = yytext;
    break;
  }
// set right since left is already set
  formatDef.right += yytext;
 
  if(formatDef.suppress)
    setPendingToken(CWebBisonParser::make_SUPPRESSED_FORMAT_DEF(formatDef, parserLocation));
  else
    setPendingToken(CWebBisonParser::make_FORMAT_DEF_BEGIN(formatDef, parserLocation));

  return CWebBisonParser::make_FREE_TEXT(freeTextSave, parserLocation);
}

 /* @d */
 /* macro definition starts with name */
 /* macro name and parameters returned as MacroName token */

 /* space after macro name means no params before macro body */
<MACRO_BEGIN>{identifier}" " {
  BEGIN(MACRO_BODY);
  parserLocation.columns(yyleng);
  macro.name.assign(yytext, yyleng - 1);
  macro.text += yytext;
  return CWebBisonParser::make_MACRO_NAME_PARAMS(macro, parserLocation);
}

 /* parens after macro name is params list that could be empty */
<MACRO_BEGIN>{identifier}"(" {
  BEGIN(MACRO_PARAMS);
  parserLocation.columns(yyleng);
  macro.name.assign(yytext, yyleng - 1);
  macro.text += yytext;
}

 /* leading whitespace before macro name */
<MACRO_BEGIN>" "* {
  parserLocation.columns(yyleng);
  macro.text += yytext;
}

 /* close parens ends macro params list */
<MACRO_PARAMS,MACRO_PARAMS_SEPARATOR>")" {
  BEGIN(MACRO_BODY);
  parserLocation.columns(yyleng);
  macro.text += yytext;
  return CWebBisonParser::make_MACRO_NAME_PARAMS(macro, parserLocation);
}

 /* save whitespace inside params list */
<MACRO_PARAMS,MACRO_PARAMS_SEPARATOR>" "+ {
  parserLocation.columns(yyleng);
  macro.text += yytext;
}

 /* save macro parameter */
<MACRO_PARAMS>{identifier} {
  BEGIN(MACRO_PARAMS_SEPARATOR);
  parserLocation.columns(yyleng);
  macro.params.push_back(yytext);
  macro.text += yytext;
}

 /* save macro parameter comma separator */
<MACRO_PARAMS_SEPARATOR>, {
  BEGIN(MACRO_PARAMS);
  parserLocation.columns(yyleng);
  macro.text += yytext;
}

 /* escape newlines inside macro */
<MACRO_PARAMS,MACRO_PARAMS_SEPARATOR>\n {
  parserLocation.lines();
  if(escapeMacroNewlines) {
    macro.text += " \\\n";
  } else {
    macro.text += yytext;
  }
}

 /* slurp macro body */
<MACRO_BODY>[^@/\n"]* {
  parserLocation.columns(yyleng);
  if(!escapeMacroNewlines) {
    tmpString += yytext;
    break;
  }
  if(haveUnescapedNewline) {
    tmpString += " \\\n";
    haveUnescapedNewline = false;
  }
  tmpString += yytext;
}

 /* newline handling */
 /* escape last unescaped newline and set flag for this newline */
<MACRO_BODY>\n {
  parserLocation.lines();
  if(!escapeMacroNewlines) {
    tmpString += yytext;
    break;
  }
  if(haveUnescapedNewline)
    tmpString += " \\\n";
  haveUnescapedNewline = true;
}

 /* @i include file code */
 /************************************************************************/
<INCLUDE_FILE_START>" "* {
 includeFile.text += yytext;
}

 /* quoted filename */
<INCLUDE_FILE_START>\"[^\n]+\" {
  includeFile.file.assign(yytext + 1, yyleng - 2);
  includeFile.quoted = true;
  includeFile.text += yytext;
  BEGIN(INCLUDE_FILE_SKIP_TO_EOL);
}

 /* unquoted filename */
<INCLUDE_FILE_START>[^ \n]+ {
  includeFile.file.assign(yytext);
  includeFile.text += yytext;
  BEGIN(INCLUDE_FILE_SKIP_TO_EOL);
}

 /* ignore to end of line */
<INCLUDE_FILE_SKIP_TO_EOL>.*\n {
 parserLocation.lines();
 includeFile.trailingText.assign(yytext, yyleng - 1);
 includeFile.text += yytext;
 setPendingToken(CWebBisonParser::make_INCLUDE_FILE(includeFile, parserLocation));
 return CWebBisonParser::make_FREE_TEXT(freeTextSave, parserLocation);
}
 /************************************************************************/

 /* c comments */
 /************************************************************************/

 /* comment text free of control codes and inner c context blocks */
<C_COMMENT>{

  [^*|@\n]* {
    parserLocation.columns(yyleng);
    tmpString += yytext;
  }

 /* comment text with bunch of stars */
  "*"+[^/\n] {
    parserLocation.columns(yyleng);
    tmpString += yytext;
  }

 /* closing delimiter of a c comment */
  "*"+"/" {
    parserLocation.columns(yyleng);
    setPendingToken(CWebBisonParser::make_C_COMMENT_END(yytext, parserLocation));
    return CWebBisonParser::make_FREE_TEXT(tmpString, parserLocation);
  }

 /* | is inner c open and close delimiter */
  "|" {
    parserLocation.columns(yyleng);
    setPendingToken(CWebBisonParser::make_INNER_C_CONTEXT_DELIM(yytext, parserLocation));
    return CWebBisonParser::make_FREE_TEXT(tmpString, parserLocation);
  }

}

 /* c++ comments */
 /************************************************************************/

 /* comment text free of control codes and inner c context blocks */
<CPLUSPLUS_COMMENT>{

  [^@|\n]* {
    parserLocation.columns(yyleng);
    tmpString += yytext;
    return CWebBisonParser::make_FREE_TEXT(tmpString, parserLocation);
  }

 /* closing delimiter of a c++ comment */
  \n {
    parserLocation.lines();
    setPendingToken(CWebBisonParser::make_CPLUSPLUS_COMMENT_END(yytext, parserLocation));
    return CWebBisonParser::make_FREE_TEXT(tmpString, parserLocation);
  }

 /* | is inner c open and close delimiter */
  "|" {
    parserLocation.columns(yyleng);
    setPendingToken(CWebBisonParser::make_INNER_C_CONTEXT_DELIM(yytext, parserLocation));
    return CWebBisonParser::make_FREE_TEXT(tmpString, parserLocation);
  }

}

<C_STRING_CHARS>{

 /* keep going unless there's a backslash or doublequote or newline or @ */
  [^\\"\n@]* {
    parserLocation.columns(yyleng);
    tmpString += yytext;
  }

 /* match escaped backslashes to prevent spurious escaped quote */
  (\\\\)+ {
    parserLocation.columns(yyleng);
    tmpString += yytext;
  }

 /* match escaped quote and keep going */
 /* quote escaped in brackets for vim syntax */
  \\[\"] {
    parserLocation.columns(yyleng);
    tmpString += yytext;
  }

 /* don't care about any other backslash sequences */
  \\ {
    parserLocation.columns(yyleng);
    tmpString += yytext;
  }

 /* must be closing quote */
  \" {
    parserLocation.columns(yyleng);
    setPendingToken(CWebBisonParser::make_DOUBLE_QUOTE(yytext, parserLocation));
    return CWebBisonParser::make_FREE_TEXT(tmpString, parserLocation);
  }

  \n {
    parserLocation.lines();
    throw CWebBisonParser::syntax_error(parserLocation, "newline not allowed in c string \"" + tmpString + "\"");
  }

 /* unescape @ control escape */
  @@ {
    parserLocation.columns(yyleng);
    tmpString += "@";
  }

}

 <*><<EOF>> {
  if(debug() != 0)
    print("CWebLexer.{}.{}: eof text \"{}\"\n", __func__, __LINE__, tmpString);
  if(parserState.includeFileState == IncludeFileState::reading) {
    includeFileEnd();
    parserState.includeFileState = IncludeFileState::eof;
  } else {
    setPendingToken(CWebBisonParser::make_YYEOF(parserLocation));
  }
  return CWebBisonParser::make_FREE_TEXT(tmpString, parserLocation);
 }

%%

// appears at very bottom of generated cwebbisonparser.v4.flex.cpp file
// code or lexer methods that need symbols defined and generated by flex is placed or #included here

#include "flexlexer/v4/cweblexer.methods.v4.h"
