# Permaweb

A framework for a personal website, designed to last for decades, if you have basic Unix skills.

# How to use it 

I have yet to add some good examples, but you can get some of the idea from reading the tests.

# How to run the tests

```
make test
```

# Presentation

In lieu of better documentation, you can browse a presentation made at [Our Networks 2024](https://2024.ournetworks.ca/) in Vancouver, Canada, on 2024-06-24. You can browse my [Google Slides](https://docs.google.com/presentation/d/1Gde7SVdqOWxZ0J_2nnZgCmewxYqKj7Lin4H64TVEz2g/edit?usp=sharing), or the static [PDF document](presentation/permaweb.pdf) here.

[<img src="presentation/preview.png">](presentation.pdf)

There are no notes, but the discussion is similar to the discussion below, with more diagrams.

# "Free as in puppy"

This software is available under the [MIT License](LICENSE). You can consider it open source.

Be aware that this software is given to you, a Unix hacker, to modify and suit your own needs. The entire point of this software is that it is so low maintenance, that you can do that yourself, given basic Unix skills.

Pull requests will likely be ignored capriciously. This software is deliberately hearkening back to an older model of free software. I am not taking on a community, and probably do not want one. Let this software spread like a vine, or let it just be a simple potted plant sitting on my windowsill. Fork the software, and do as thou wilt.

# Background

In 2012, I redid my personal website using the currently-hot static site generator. 

Being a hacker, I made some hacker-friendly choices, with longevity and standards compliance in mind.

I used Octopress, which was then the currently-hot static site framework, which cobbled together the following:

* Jekyll 
* Markdown/YAML
* Ruby
* CSS, SCSS, LESS
* miscellaneous Octopress extensions
* Pygments for syntax coloring
* [Octopress-Flickr](https://github.com/neilk/octopress-flickr); a plugin I created to link and embed Flickr-hosted images and image sets. It was reasonably popular at the time.
* Fancybox.js to expand images and show slideshows
* Tweets embedded with the official Twitter Javascript API

Over the next five or six years, nearly *every one of these broke*. The maintainers vanished, the technology world moved on, and in the case of Twitter... the less said, the better.

## Fragility 

The worst part was that every time one of these things broke, I couldn't update the website at all. I'd have to go spelunking inside the innards of Octopress to fix, replace, or remove it.

I thought I was making hacker-friendly choices? This was a nightmare.


## What went wrong?

I came across the [Permacomputing manifesto](https://permacomputing.net/) around this time. I began thinking about what that would mean for a personal website. While I have many issues with the concept of "permaculture" — it's only a real solution for people with legal access to property - it gives us interesting constraints to creativity. In particular:

* Have few dependencies
* Avoid pseudosimplicity
* **Accumulate wisdom and experience rather than codebase**
* Human-scale
* Hope for the best; prepare for the worst
* **Design for descent (degrade gracefully)**

So what would a website designed for the next thirty years look like? What I embraced a little more time and trouble, and less convenience? How do I ensure that the site is easily repairable?

## Principles 

### Few required dependencies

None that you don't get with a basic Linux or MacOS system today. Yes we could freeze a system in time with a tool like `docker` or NixOS. 

Do you really trust that `docker` or NixOS will be around in ten years? 

### Required dependencies should have a long expected lifetime

Also, as a rule of thumb, you should expect that you're somewhere in the middle of a technology's lifetime. If it's been around for five years, you can expect it will be viable for five more. `bash` and `make` have a continuous history since the 1980s, so they are likely going to be around for decades.

That means the basic kernel is written in `bash` and `make`. Yes, `bash`. I hate it as much as you do. However, with modern IDEs and shellcheck, it is tolerable.

### Embrace visual pleasure, fun, and whimsy

I greatly admire [Dan Luu](https://danluu.com/)'s writing, and his website is certainly low maintenance. But his website is nearly unreadable on many platforms.

It should be possible to indulge our creativity, fashion, and even trends, without sacrificing long-term viability.

### The site *always* works

If any part of the system breaks, it doesn't affect the viability of the site. Every enhancement can break and it all still works.

This mandates that the "source" for the website has to either be in the final format, or something else that's readable on the web, like Markdown.  

After many experiments I decided the best choice was HTML. That is; I will write the blog in very basic, plain HTML, and then run a series of transformations on it to build readable, enhanced, attractive HTML.

### The site is always easy to update, but we don't sacrifice the principles above for convenience

It should be possible to update one's website in much less than a minute. However, optimizing for instant local views or publishing is not as important. I am not publishing a news website, and I update my blog or projects only a few times a year at most.

## Implementation choices

### Minimal "kernel"

#### The failure-embracing transformation pipeline

This is the heart of the system. I think I might have accidentally created a new basic Unix paradigm here; I've asked around and never seen it anywhere else. 

The idea here is that any transformation should be optional. So we create a pipeline, where if any command returns failure (a non-zero return), the output is simply the original input. 

For example, let's say we had a transformation that added a navigation header to some raw HTML. If the navigation-header-adding part succeeds, we get the enhanced HTML as output. If the navigation-header-adding part fails, we get the original, unenhanced HTML as output.

It's a bit hard to see in the code itself, but if it were extracted from the kernel, it would look like this:

```bash
#!/bin/bash
# If command succeeds, return output
# If command fails, return input

# NOTE: this code is deliberately simple and vulnerable to many issues.
# It is just to illustrate the concept

if [ $# -ne 1 ]; then
    echo "Usage: $0 <executable>" >&2
    exit 1
fi

EXECUTABLE="$1"

# Read stdin into a variable without using cat
read -d '' -r INPUT

# Run once, capturing output and using exit code to determine which to echo
OUTPUT=$("$EXECUTABLE" <<< "$INPUT") && echo "$OUTPUT" || echo "$INPUT"

```

The benefit here is that now we simply don't care about the longevity of each transformation. We can use fancy, fun, trendy tools if we want. If they break two years later, the site still works and we can still update the site, even without removing that step from the pipeline.

#### Pipeline defined as a series of scripts

Each script is expected to be a very well-behaved unix program. It accepts HTML (or whatever else it processes) on standard input, prints errors and metadata to standard error, prints its transformed output to standard out, and returns a standard exit code.

The scripts are defined in a paradigm familiar to old-school hackers; a directory where the scripts sort in the order they are supposed to be run, e.g.

```
10_addCharset.sh       # add meta charset to header
15_addStyle.sh         # add styles to header
17_addLanguage.sh      # add meta language to header
20_addH1.sh            # extract header title, add H1 tag just after the open of the body tag
30_addNavigation.sh    # add navigation links just after the open of the body tag
90_addFooter.sh        # add footer just before close of body tag
```

#### Highly cacheable transformations

These transformations are more expensive than other frameworks, because we parse and validate HTML at every step. We want to be able to write without too much interruption of flow.

To this end, I can't believe I did this, but I made a content-addressable process caching database in `bash`. 

The structure is fairly simple. A cache directory is created, by default, `.cache`, which will persist between builds of the blog.

There are two directories inside that, called `exec` and `object`

`exec` caches the full results of executions of one script operating on one file:

* the entries in `exec` are directories, named thusly `<sha1 hash of input file>_<sha1 hash of script>`.
* inside each directory, there are three files:
* * 1 is the output captured from standard out
* * 2 is the output captured from standard error
* * exitCode is a simple text file containing one integer, the exit code of the transformation.

Each of the output captured is a symbolic link pointing to an entry in `object`, which is a simple content-addressable flat directory. (I'll probably have to hash entries eventually, this directory is getting very lengthy).

This way, the `permaweb` framework can run the entire pipeline, and examine if it's run each script before on some input. 

If it has, then it can rapidly proceed to the next step without actually running anything.

If you have a step that is consistently failing, it will also print the errors to STDERR every time, so you don't forget that there's a broken step. But you'll still get, at the very minimum, your source HTML, which is publishable as is.

## Limitations?

Sitewide metadata does not fit in this framework well, such as 
- Favicons
- RSS or other feed formats
- Sitemaps 

Even navigation links are a bit painful as they are not simple pipeline transformations; one has to look to the 'sibling' documents to build the list of links.

I'm not sure if I'm going to give this job to custom scripts that run outside the permaweb framework, or if it's just not worth optimizing it at all. It is possible to just keep those as static files, edited as needed. I do not update the sections of my personal website very frequently.

The spirit of `permaweb` is to embrace some maintenance for longevity. If your time horizon is years, or decades, and you only have one site to manage, it's far less work to simply update the navigation links of your website by hand. 

