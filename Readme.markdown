pacer-xml
=========

This Pacer plugin is designed to make it dead-simple to import any
arbitrary XML file (no matter how bizarre) into any graph database
supported by Pacer.

This library evolved out of my need to be able to easily pull in sample
data when demoing Pacer. GraphML is pretty rare and what I've been able
to find is mostly pretty lame anyway, but raw XML seems to be everywhere
(just check out [DATA.GOV](http://www.data.gov/)).


Usage
-----

I suggest looking at the implementation of the below sample to see how
I've used pacer-xml there.

There are 2 key methods:

`Pacer.xml(file, start_section = nil, end_section = nil)`

```
file:          String | IO
  String           path to an xml file to read
  IO               an open resource that responds to #each_line
start_section: String | Symbol | Regex | Proc  (optional)
  String | Symbol  name of xml tag to use as the root node of each
                   section of xml. The end_section will automatically be
                   set to the closing tag.  This uses very simple regex
                   matching.
  Regex            If it matches, start the section from this line
  Proc             proc { |line| }
                   If it results in a truthy value, starts collecting
                   lines for the next section of xml.
end_section:   Proc  (optional)
  Regex            If it matches, end the section including this line
  Proc             proc { |line, lines| }
                   - If it results in a truthy value to indicate that the
                     current line is the last line in a section.
                   - if it results in an Array, pass the result of
                     joining the array to Nokogiri for the next section.
```

If the parser is building a section when it gets to the end of the file,
it will call the `end_section.call(nil, lines)`. To prevent the final
section from being processed, return `[]`.

Returns a Pacer Route to a series of Nokogiri::XML::Elements. Each
element is the root element of the its document. By default, chunks are
delimited by the presence of `<?xml`.


`xml_route.import(graph, opts = {})`

```
graph: PacerGraph   The graph to load the data into.
opts:  Hash
  :cache  false | Hash
    false              disable caching
    stats: true        enable occasional dump of cache info
  :rename Hash         map of { 'old-name' => 'new-name' }
  :html   Array        set of tag names to treat as containing HTML
  :skip   Array        set of tag or attribute names to skip
```

Baked-in Sample
---------------

This library started out with me tackling a chunk of [Patent Grants](https://explore.data.gov/Business-Enterprise/Patent-Grant-Bibliographic-Text-1976-Present-/8du5-jxih)
data, and my first attempt at importing it was with a hand-crafted set
of rules that walked the XML, creating graph elements along the way.
That was fairly painful and turned out to be very slow as well. My
second attempt evolved into this tool. The cool thing is that by the
end, everything specific to the patent grants data set was just a few
lines of configuration on top of a very powerful streaming XML parsing
tool.

I encourage you to check out the sample data, simply install this gem
and start up IRB, then:

```ruby
require 'pacer-xml'

graph = PacerXml::Sample.load_100
```

That will download and extract a 100M xml file full of 2 weeks of patent
grants data, then create a graph with the first 100 patents, including
every piece of data in the file.

I encourage you to take a look at [how it was done](https://github.com/xnlogic/pacer-xml/blob/master/lib/pacer-xml/sample.rb).

Once you've created a graph from the data, it may be useful for you to
check out how it's structured. Pacer's got a handy tool built in to do
that, `Pacer::Utils::GraphAnalysis.structure graph`, but let's go one
step further and visually analyze the graph. If we run the command
below, we'll see the same results as the GraphAnalysis, but it will
export a graphml file that we can load into yEd, an excellent free graph
visualization tool:

```ruby
PacerXml::Sample.structure! graph
# ... lots of output ...
#=> #<PacerGraph tinkergraph[vertices:90 edges:112]
```

The new file in your working directory is called
`patent-structure.graphml`. Open that file in yEd. You'll see a single
box... Fortunately, laying it out is fairly simple:

1. Tools / Fit Node To Label
1. OK
1. Layout / Hierarchical...
1. Labelling Tab / set Edge Labelling to Hierarchic
1. OK

Cool!

Contextual Help
---------------

Back to Pacer, there's lots to learn about Pacer. The best way to do
that is to use Pacer's own inline help:

* Use `Pacer.help` for general help
* Get into a general section with `Pacer.help :section`
* Get contextual help with `graph.v.map.help`
* Get more contextual help with `graph.v.map.help :section`

Contextual help was only added recently so it's not complete yet but
it's developing quickly and contributions are very welcome!

More
-----

To play with the xml tools themselves, try out the following commands:

```ruby
xml_route = PacerXml::Sample.xml(nil, start_rule, end_rule)

importer = PacerXml::Sample.importer
```

Performance Notes
-----------------

This section uses the `PacerXml::Sample.load_all` method. The `load_100`
method runs in just a couple of seconds.

The default sample file contains 3019840 lines representing 4479
documents. Running under the simple `bundle exec irb` command on a MBP
2.3 GHz i7, here are some quick timings (in seconds) for operations on
the entire file:

```
=> 8.36    iterate through 3019840 lines
=> 28.534  reduce the lines to 4479 arrays of lines
=> 29.753  join each array of lines into a string
=> 34.788  parse each string into a Nokogiri XML document
=> 812.732 create a graph, producing 494659 vertices and 629690 edges
```

Starting up with `bundle exec jruby --server -J-Xmx2048m -S irb`
slightly improves performance of the import but does not appear to
affect Pacer or Nokogiri's performance:

```
=> 34.857  parsed XML documents
=> 780.828 created graph
```
