#!/usr/bin/env node

var fs    = require('fs');
var path  = require('path');
var embed = require('../index.js');

options = {
    verbose: false,
    replace: {}
}

function makeSmInline(name) {
  if (name.startsWith("-v")) {
    options.verbose = true
    return
  }

  if (name.startsWith("-P")) {
    var sub = name.substring(2);
    var pos = sub.indexOf('=')
    var from = sub.substring(0, pos)
    var to = sub.substring(pos+1)

    if (options.verbose)
        console.log("Add replacement '%s' => '%s'", from, to)
    options.replace[from] = to
    return
  }

  var src = fs.readFileSync(name, 'utf8');
  var srcEmbed = embed(src, options);
  if(src != srcEmbed) {
    fs.writeFileSync(name + '.bak', src);
    fs.writeFileSync(name, srcEmbed);
  }
}

process.argv.slice(2).forEach(makeSmInline);
