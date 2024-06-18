#!/usr/bin/env node

const fs = require('fs');
const { JSDOM: jsdom } = require("jsdom");


async function main() {
    let dom = new jsdom(fs.readFileSync('/dev/stdin').toString());
    const doc = dom.window.document;

    const title = doc.querySelector('title');

    title.prepend(doc.createTextNode("Neil K · "));

    process.stdout.write(dom.serialize());
}

main().catch(console.error);


