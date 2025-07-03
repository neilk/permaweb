The goal here was to support incremental and fast updates while also supporting concepts like RSS and Sitemaps.

Previously, permaweb was simple:

One origin file in HTML -> pipeline of scripts -> one output file

But RSS and Sitemaps aren't like that:

Many files -> ??? -> one output file

Furthermore, even if you have a custom script to do the above which runs after every content rebuild, it's not fast! To make RSS in the permaweb paradigm, you have to read every HTML file, parse out its metadata, then rewrite the entire RSS file.

The potential solution here is to use a map-reduce pattern and leverage the existing caching layer. 

Here are the conventions:

In your permaweb project, you have a directory named `reducers`. 

Inside `reducers`, you then have paths which indicate what file we are to generate. For instance, if we want to make `/feeds/rss.xml`, then in reducers, you have this directory structure. These are ALL directories.

```
reducers/
   +-- feeds/
       +-- rss.xml/
```

Inside the last directory, we then have scripts. Similar to how scripts work for the single-pipeline, we have, by convention, `map`, and `reduce`. You are allowed to have simply-named scripts like `map` or `map.sh` or `reduce.py`, as long as they are executable. If your scripts need ancillary files, the best practice is to use directories named `map` or `reduce` and stuff all the files in there, with the actual executable named `main` or `main.*` The reason is so we can hash all the ancillary files to be part of the content-hash for the generated files. TLDR: if you are basing your outputted file from a script and a template, we want to invalidate the cache for that when you change the template.

```
reducers/
  +-- feeds/
    +-- rss.xml/
       +-- map.py
       +-- reduce/
         +-- main.py
         +-- template.xml
```

And then you can have several of these reducers:

```
reducers/
  +-- feeds/
     +-- rss.xml/
     +-- atom.xml/
  +-- sitemap.xml/
```

This remains fast and efficient because we hash at the map stage _and_ at the reduce stage. Imagine doing an RSS feed.

```
blog/file1.html  --> metadata extracted and cached  }
blog/file2.html  --> metadata extracted and cached   }  --> metadata merged to feeds/rss.xml and cached
blog/file3.html --> metadata extracted and cached   }
```

Consequently, if only `file3.html` changes, we will re-extract its metadata and then rewrite `feed/rss.xml` in toto.