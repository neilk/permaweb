#!/usr/bin/env node

const fs = require('fs');
const path = require("path");
const { JSDOM: jsdom } = require("jsdom");

let urlsThatPointHere = [];
if (process.env.BREAKAWAY_SOURCE_PATH) {
    const fullUrl = path.join("/", process.env.BREAKAWAY_SOURCE_PATH);
    urlsThatPointHere = urlsThatPointHere.concat([
        fullUrl,
        fullUrl.replace(/\/$/, ""),
        fullUrl.replace(/\/index.html$/, "/"),
        fullUrl.replace(/\/index.html$/, ""),
    ]);
}

async function main() {
    let dom = new jsdom(fs.readFileSync('/dev/stdin').toString());
    const { document } = dom.window;

    let navigationString = fs.readFileSync(`${__dirname}/navigation.html`).toString();
    let navigation = jsdom.fragment(navigationString);
    
    for (const anchor of navigation.querySelectorAll("nav a")) {
        if (urlsThatPointHere.includes(anchor.href)) {
            anchor.classList.add("selected");
        }
    }

    let body = document.querySelectorAll('body')[0];
    body.prepend(navigation);

    process.stdout.write(dom.serialize());
}

main().catch(console.error);


