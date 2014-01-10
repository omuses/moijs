/*
 * Modelica lexer implemented as Jison dummy parser.
 * Contains a tokenizer for CodeMirror with special treatment of multi-line comments and strings.
 * Generate with:
 * $ jison molexer.jison molexer.jisonlex -o codemirror/mode/modelica/modelica.js
 */

/* Copyright (c) 2013 -- 2014 Ruediger Franke */

%%

/* dummy parser rule to make the code generation work */
dummy: ;

%%

/* Define Modelica mode for CodeMirror if it has been loaded */
if (typeof CodeMirror !== "undefined") {
  CodeMirror.defineMode("modelica", function () {

    // mapping of tokens to styles
    var TOKEN_STYLE = {
      'COMMENT':          "comment",
      'CONNECT':          "builtin",
      'KEYWORD':          "keyword",
      'UNSIGNED_NUMBER':  "number",
      'STRING':           "string",
      'HTML':             "meta",
      'TAG':              "tag"
    };

    var builtins = [
      "Integer", "String", "abs", "acos", "actualStream", "asin", "atan", "atan2",
      "assert", "cardinality", "ceil", "change", "cos", "cosh", "delay", "der",
      "edge", "exp", "floor", "getInstanceName", "homotopy", "initial", "inStream",
      "integer", "log", "log10", "mod", "pre", "reinit", "rem", "sample",
      "semiLinear", "sign", "sin", "sinh", "smooth", "spatialDistribution", "sqrt",
      "tan", "tanh", "terminal"
    ];

    return {
      // the state covers information spanning multiple lines
      startState: function(/*basecolumn*/) {
        return {
          inComment: false,
          inString: false,
          inHTML: false
        };
      },

      // take a stream for a line, advance by one token and return its style
      token: function (stream, state) {
        var token;
        stream.eatSpace();

        // treat comments as the lexer would eat them and as they may span multiple lines
        if (!state.inString && stream.string.substring(stream.pos).slice(0, 2) === "/*") {
          state.inComment = true;
          stream.pos += 2;
        }
        if (state.inComment) {
          while (stream.skipTo("*")) {
            stream.next();
            if (stream.next() === "/") {
              state.inComment = false;
              return "comment";
            }
          }
        }
        if (state.inComment || stream.string.substring(stream.pos).slice(0, 2) === "//") {
          stream.skipToEnd();
          return "comment";
        }

        // treat strings as they may span multiple lines
        if (!state.inComment && !state.inString && stream.peek() === '"') {
          state.inString = true;
          stream.pos += 1;
          if (stream.string.substring(stream.pos, stream.pos+5).toLowerCase() === "<html") {
            state.inHTML = true;
            return TOKEN_STYLE['HTML'];
          }
          else
            state.inHTML = false;
        }
        if (state.inString) {
          if (state.inHTML && stream.peek() === '<') {
            var close = stream.string.indexOf('>', stream.pos);
            stream.pos = close >= 0? close + 1: stream.pos + 1;
            return TOKEN_STYLE['TAG'];
          }
          outer: while (!stream.eol()) {
            stream.eatWhile(/[^"<\\]/);
            switch (stream.peek()) {
            case '"':
              // terminate string
              stream.pos ++;
              state.inString = false;
              break outer;
            case '<':
              // break for html tag or skip it
              if (state.inHTML) {
                break outer;
              }
              stream.pos ++;
              break;
            default:
              // skip quoted character
              stream.pos += 2;
              break;
            }
          }
          return state.inHTML? TOKEN_STYLE['HTML']: TOKEN_STYLE['STRING'];
        }

        // per default use the lexer to identify the next token
        try {
          parser.lexer.setInput(stream.string.substring(stream.pos));
          parser.lexer.mo_kind = null;
          token = parser.lexer.lex();
          if (token === 'END_IDENT') {
            token = 'END';
            stream.pos += 3;
          }
          else
            stream.pos += parser.lexer.yylloc.last_column;
          if (token === 'IDENT' && builtins.indexOf(parser.lexer.yytext) >= 0)
            return "builtin";
        }
        catch (err) {
          console.log(err.toString());
          stream.skipToEnd();
          return "error " + err;
        }

        return TOKEN_STYLE[token] || TOKEN_STYLE[parser.lexer.mo_kind];
      },

      // declarations for CodeMirror.fold.comment, see comment-fold.js
      blockCommentStart: "/*",
      blockCommentEnd: "*/",
      braceOpen: "(",
      braceClose: ")",
      //lineComment: "//",
      fold: "modelicaBrace", // evaluated by foldCode function

      foldAnnotations: function (cm) {
        var lastLine = cm.lastLine();
        for (var i = 0; i < lastLine; i++) {
          if (cm.getLine(i).indexOf("annotation") >= 0)
            editor.foldCode(i);
        }
      }
    };
  });

  CodeMirror.defineMIME("text/x-modelica", "modelica");

  CodeMirror.registerHelper("fold", "modelicaBrace", function(cm, start) {
    var mode = cm.getModeAt(start);
    var startToken = mode.braceOpen || "{", endToken = mode.braceClose || "}";
    var line = start.line, lineText = cm.getLine(line);
    var startCh, tokenType;

    for (startCh = start.ch;;) {
      startCh = lineText.indexOf(startToken, startCh) + 1;
      if (startCh == 0) return;
      tokenType = cm.getTokenTypeAt(CodeMirror.Pos(line, startCh));
      if (!/^(comment|string)/.test(tokenType)) break;
    }

    var count = 1, lastLine = cm.lastLine(), end, endCh;
    outer: for (var i = line; i <= lastLine; ++i) {
      var text = cm.getLine(i), pos = i == line ? startCh : 0;
      for (;;) {
        var nextOpen = text.indexOf(startToken, pos), nextClose = text.indexOf(endToken, pos);
        if (nextOpen < 0) nextOpen = text.length;
        if (nextClose < 0) nextClose = text.length;
        pos = Math.min(nextOpen, nextClose);
        if (pos == text.length) break;
        if (cm.getTokenTypeAt(CodeMirror.Pos(i, pos + 1)) == tokenType) {
          if (pos == nextOpen) ++count;
          else if (!--count) { end = i; endCh = pos; break outer; }
        }
        ++pos;
      }
    }
    if (end == null || line == end && endCh == startCh) return;
    return {from: CodeMirror.Pos(line, startCh),
            to: CodeMirror.Pos(end, endCh)};
  });
}
