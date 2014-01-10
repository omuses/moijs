Modelica in JavaScript &ndash; MoiJS
====================================

Moijs provides a [Modelica](www.Modelica.org) parser in JavaScript. This enables the processing of Modelica definitions in a Web browser. Moijs can also run server-side or on the command line using a tool like [Node.js](nodejs.org).

The Modelica parser `moparser.js` is generated with [Jison](zaach.github.io/jison/) out of the grammar in `moparser.jison` and the lexical specification in `molexer.jisonlex`.

CodeMirror
----------

A Modelica editing mode for [CodeMirror](codemirror.net) is generated from `molexer.jison` and `molexer.jisonlex`.

Examples running in a Web browser
---------------------------------

- `moparse.html` &ndash; HTML page using CodeMirror and invoking `moparser.js`

Examples running in Node.js
---------------------------

- `moparse.js` &ndash; invoke `moparser.js` for files of a Modelica package or console input 
- `molex.js` &ndash; tokenize console input
