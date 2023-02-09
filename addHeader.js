const fs = require('fs');
const htmlParser = require('node-html-parser');



let boilerPlateHeadersString = fs.readFileSync('./boilerPlateHeader.html').toString();
let boilerPlateHeaders = htmlParser.parse(boilerPlateHeadersString);

let htmlString = fs.readFileSync('/dev/stdin').toString();
let dom = htmlParser.parse(htmlString);

let head = dom.querySelectorAll('head')[0];
head.appendChild(boilerPlateHeaders);

process.stdout.write(dom.toString());

