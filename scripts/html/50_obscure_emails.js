#!/usr/bin/env node

const fs = require('fs');
const { JSDOM: jsdom } = require("jsdom");

const reverseClass = 'reverse';

const styleString = `<style type="text/css">
    a.${reverseClass} {
        unicode-bidi: bidi-override; 
        direction: rtl;
    }
</style>`;
const style = jsdom.fragment(styleString);


async function main() {
    let dom = new jsdom(fs.readFileSync('/dev/stdin').toString());
    const { document } = dom.window;

    const head = document.querySelectorAll('head')[0];
    head.append(style);

    const body = document.querySelectorAll('body')[0];

    body.querySelectorAll('a').forEach(anchor => {
        const href = anchor.getAttribute('href');
        if (href.startsWith('mailto:')) {

            // Reverse text
            const classes = new Set(anchor.className.split(' '));
            classes.add(reverseClass);
            anchor.className = [...classes].sort().join(' ');
            anchor.textContent = anchor.textContent.split('').reverse().join('');

            // obscure mailto: link
            const address = href.substr('mailto:'.length);
            const obscuredAddress = address.split('').map(char => `&#${char.codePointAt(0)}`);
            anchor.setAttribute('href', `mailto:${obscuredAddress}`);
        }

    });

    process.stdout.write(dom.serialize());
}

main().catch(console.error);