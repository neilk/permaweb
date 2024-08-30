# Permaweb

A framework for a personal website to last 30 years

# How to use it 

I have yet to add some good examples, but you can get some of the idea from reading the tests.

# How to run the tests

```
make test
```

# Presentation

This was presented at Our Networks 2024 in Vancouver, BC on 2024-06-24. You can read my [slides](https://docs.google.com/presentation/d/1Gde7SVdqOWxZ0J_2nnZgCmewxYqKj7Lin4H64TVEz2g/edit?usp=sharing) (without notes, but the content is similar to the discussion below).

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

Have few dependencies
Avoid pseudosimplicity
**Accumulate wisdom and experience 
rather than codebase**
Human-scale
Hope for the best; prepare for the worst
Design for descent (degrade gracefully)

So what would a website designed for the next thirty years look like? What I embraced a little more time and trouble, and less convenience? How do I ensure that the site is easily repairable?

## No required dependencies

None that you don't get with a basic Linux or MacOS system today. That means the basic kernel is written in `bash` and `make`. Yes, `bash`. I hate it as much as you do. However, with modern IDEs and shellcheck, it is tolerable.

## Embrace visual pleasure, fun, and whimsy

I greatly admire [Dan Luu](https://danluu.com/)'s writing, and his website is certainly low maintenance. But his website is nearly unreadable on many platforms.

It should be possible to indulge our creativity, fashion, and even trends, without sacrificing long-term viability.

## The site *always* works

If any part of the system breaks, it doesn't affect the viability of the site. Every enhancement can break and it all still works.

This mandates that the "source" for the website has to either be in the final format, or something else that's readable on the web, like Markdown.  

After many experiments I decided the best choice was HTML. That is; I will write the blog in very basic, plain HTML, and then run a series of transformations on it to build readable, enhanced, attractive HTML.

## The site is always easy to update, but we don't sacrifice the principles above for convenience

It should be possible to update one's website in much less than a minute. However, optimizing for instant local views or publishing is not as important. I am not publishing a news website, and I update my blog or projects only a few times a year at most.


## Minimal "kernel"

### The failure-embracing transformation pipeline

This is the heart of the system. I think I might have accidentally created a new basic Unix paradigm here; I've asked around and never seen it anywhere else. 

The idea here is that any transformation should be optional. So we create a pipeline, where if any command returns failure (a non-zero return), the output is simply the original input. 

For example, let's say we had a transformation that added a navigation header to some raw HTML. If the navigation-header-adding part succeeds, we get the enhanced HTML as output. If the navigation-header-adding part fails, we get the original, unenhanced HTML as output.

It's a bit hard to see in the code itself, but if it were extracted from the kernel, it would look like this:

```bash
# If command succeeds, return output
# If command fails, return input
pipeOrPass() {
    local tmp_input tmp_output

    tmp_input=$(mktemp)
    tmp_output=$(mktemp)

    trap 'rm -f "$tmp_input" "$tmp_output"' EXIT

    cat > "$tmp_input"

    if "$@" < "$tmp_input" > "$tmp_output"; then
        cat "$tmp_output"
    else
        cat "$tmp_input"
    fi
}
```

The benefit here is that now we simply don't care about the longevity of each transformation. We can use fancy, fun, trendy tools if we want. If they break two years later, the site still works and we can still update the site, even without removing that step from the pipeline.

### Pipeline defined as a series of scripts

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

### Highly cacheable transformations

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

## Limitations?

Sitewide metadata does not fit in this framework well, such as 
- Favicons
- RSS or other feed formats
- Sitemaps 

Even navigation links are a bit painful as they are not simple pipeline transformations; one has to look to the 'sibling' documents to build the list of links.

I'm not sure if I'm going to give this job to custom scripts that run outside the permaweb framework, or if it's just not worth optimizing it at all. It is possible to just keep those as static files, edited as needed. I do not update the sections of my personal website very frequently.


