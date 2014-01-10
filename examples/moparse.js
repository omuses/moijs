/*
 * Modelica parser with command line interface.
 * Invoke with:
 * $ node moparse.js [Modelica package directory]
 */

var moparser = require("../moparser").parser;
moparser.yy.parseError = function (message, details) { 
  console.log(message);
  throw new SyntaxError(message);
};

if (process.argv.length == 3) {
  // parse files
  var fs = require('fs');
  var packageDir = process.argv[2];    

  function parseFile(fileName) {
    fs.readFile(fileName, function(err, content) {
      if (err) {
        console.log("Error reading file " + fileName);
        return;
      }
      console.log(fileName);
      moparser.lexer.fileName = fileName;
      moparser.parse(content.toString());
    });    
  }

  function parseFiles(dirName) {
    fs.readdir(dirName, function(err, files) {
      if (err) {
        console.log(err);
        return;
      }
      if (files.indexOf("package.mo") === -1) {
        if (dirName === packageDir)
          // packageDir is no Modelica package directory
          console.log("Missing file " + dirName + "/package.mo");
        // some subdirectory, like Resources
        return;
      }
      files.sort().forEach(function(file) {
        if (file.indexOf(".mo", file.length - ".mo".length) !== -1) {
          parseFile(dirName + "/" + file);
          return;
        }
        fs.lstat(dirName + "/" + file,
                 function(err, stats) {
                   if (err)
                     console.log(err);
                   else if (stats.isDirectory())
                     parseFiles(dirName + "/" + file);
                 });
      });
    });
  }

  parseFiles(packageDir);
}
else {
  // get input from command prompt and log parser output
  var readline = require('readline'),
  rl = readline.createInterface(process.stdin, process.stdout);

  rl.setPrompt("moparse> ");
  rl.prompt();

  rl.on('line', function(line) {
    try {
      var result = moparser.parse(line);
      //console.log(JSON.stringify(result, undefined, 2));
      var resultString = JSON.stringify(result, function(key, value) {
        // skip track objects
        if (value && value.track)
          delete value.track;
        // add constructor name as _parserClass if key does not match
        if (typeof(value) === "object"
            && value.constructor !== Object && value.constructor !== Array
            && value.constructor.name
            !== key.charAt(0).toUpperCase() + key.slice(1)
            && key !== "typeSpecifier")
        {
          var modValue = {"_parserClass": value.constructor.name};
          for (name in value)
            modValue[name] = value[name];
          value = modValue;
        }
        // convert lists to Arrays if key matches
        else if (value instanceof Array
                 && value.constructor.name === key.charAt(0).toUpperCase() + key.slice(1))
        {
          modValue = [];
          for (name in value)
            if (name !== "constructor" && name !== "length")
              modValue.push(value[name]);
          value = modValue;
        }
        return value;
      }, 2);
      // remove some whitespaces
      resultString = resultString.replace(/\s+{/g, " {").replace(/\s+}/g, " }");
      console.log(resultString);
    }
    catch (ex) {
      if (!(ex instanceof SyntaxError))
        console.log(ex.stack);
    }
    rl.prompt();
  }).on('close', function() {
    rl.close();
    //process.exit(0);
  });
}
