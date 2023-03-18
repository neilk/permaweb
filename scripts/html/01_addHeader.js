#!/usr/bin/env node

const fs = require('fs');
const { JSDOM: jsdom } = require("jsdom");


async function main() {
    let boilerPlateHeadersString = await fs.readFileSync(`${__dirname}/header.html`).toString();
    let boilerPlateHeaders = jsdom.fragment(boilerPlateHeadersString);

    let dom = new jsdom(fs.readFileSync('/dev/stdin').toString());
    const { document } = dom.window;

    let head = document.querySelectorAll('head')[0];
    head.prepend(boilerPlateHeaders);

    process.stdout.write(dom.serialize());
}

main().catch(console.error);


