/*
 * Modelica lexer with command line interface.
 * Invoke with:
 * $ node molex.js
 */

var molexer = require("../codemirror/mode/modelica/modelica").parser.lexer;

var readline = require('readline'),
    rl = readline.createInterface(process.stdin, process.stdout);

rl.setPrompt("molex> ");
rl.prompt();

rl.on('line', function(line) {
  molexer.setInput(line);
  try {
    do {
      token = molexer.lex();
      console.log(token);
    } while (token != 'EOF');
  }
  catch (ex) {
    console.log("Failed lexing:");
    console.log(line);
    var spaces = "";
    for (var i = 0; i < molexer.yylloc.last_column; i++)
      spaces += " ";
    console.log(spaces + "^");
  }
  rl.prompt();
}).on('close', function() {
  rl.close();
  //process.exit(0);
});



