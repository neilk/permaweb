#!/usr/bin/env node

const fs = require('fs');
const { JSDOM: jsdom } = require("jsdom");


async function main() {
    let navigationString = await fs.readFileSync(`${__dirname}/navigation.html`).toString();
    let navigation = jsdom.fragment(navigationString);

    let dom = new jsdom(fs.readFileSync('/dev/stdin').toString());
    const { document } = dom.window;

    let body = document.querySelectorAll('body')[0];
    body.prepend(navigation);

    process.stdout.write(dom.serialize());
}

main().catch(console.error);


