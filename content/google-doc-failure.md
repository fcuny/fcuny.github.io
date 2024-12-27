+++
title = "Google Doc Failures"
date = 2021-04-11
+++

In most use cases, Google Doc is an effective tool to create "write once, read never" documents.

## Convenience

Google Doc (GDoc from now on) is the most common way of writing and sharing documents at my current job. It's very easy to start a new document, even more since we can now point our browser to <https://doc.new> and start typing right away.

Like most of my co-workers, I use it frequently during the day. Some of these documents are draft for some communication that I want others to review before I share with a broader audience; it can be a [Request For Comments](https://en.wikipedia.org/wiki/Request_for_Comments) for a project; meeting notes for others to read; information that I need to capture during an incident or a debugging session; interviews notes; etc.

I would not be surprised if the teams I work closely with generate 50 new documents each week.

## ETOOMANYTABS

I have a tendency of having hundreds of open tabs in my browser during the week. A majority of these tabs are GDocs, and I think this is one of the true failure of the product. Why do I have so many tabs ? There's mainly two reasons.

The first reason is a problem with Chrome's UX itself: it happily let me open the same URL as many times as I want in as many tabs, instead of sending me to the already opened tab if the document is loaded. It's not uncommon that I find the same document opened in 5 different tabs.

The second reason, and it's the most important one, I know that if I need to read or comment on a doc and I close the tab, I'll likely never find that document again, or will completely forget about it.

## Discoverability

In 'the old days', you'd start a new document in Word or LibreOffice, and as you hit "save" for the first time, you've two decisions to make: how am I going to name that file, and where am I going to save it on disk.

With GDoc these questions don't have to be answered, you don't have to name the file, and it does not matter where it lives. I've likely hundreds of docs named 'untitled' in my "drive". I also don't have to think about where they will live, because they are saved automatically for me. I'm sure there's hundreds of studies that show that these two simple steps are actually complex for many users and creates useless friction (in which folder do I store it; should I organize the documents by team, years, projects; do I name it with the date and the current project; etc.).

GDoc being a Google product, it seems pretty obvious that they would come up with a better solution: let's not organize in a strict hierarchy these files, and let's instead search for them.

Unfortunately, GDoc's search is really poor (and I'm being kind). By default most of us start by looking for some words we know are in the doc, maybe even in the title. But when working on a multiple projects that are related to the same technology, you suddenly get hundreds of documents matching your query. It's unclear how the returned set is ordered (by date ? by author ? by some scoring that is invisible to me ?).

You can also search by owners, but here is another annoying bit: I think about owner as author, so I usually type `author:foo` before realizing it does not work. And that implies you already know who's the owner of the document. In the case of TDDs (Technical Design Document), I might know which team is behind it, but rarely who's the actual author.

I could search for the title, but I rarely remember or know the name of the document I'm looking for. I could also be looking by keywords, but when working on a project with tens of related documents, you have to open all the returned docs to see which one is the correct one.

And then what about new members joining your the team ? They don't know which docs exist, who wrote them, and how they are named. They end up searching and hoping that something good will be returned.

## Workflows

More and more we create workflows around these documents: some of the docs are TDDs that are going through reviews; others are decision documents that require input from multiple teams and are pending approval; others are road map documents that also go through some review process.

As a result we create templates for all kind of documents, with usually something like "draft → reviews → approved/rejected" at the top. We expect the owner of the doc to mark in bold what's the status of the doc to help the reader understand in what state the document is. It's difficult to keep track of open actions and comments. Yes, there's a way to get a list of all of them, but it's not in an obvious place.

As a result, some engineers in my team built an external dashboard with swim lanes which captures the state of a document. We add new document with their URLs, add who are the reviewers, and we move the doc between the lanes. Now we have to operate a service and a database to keep track of the status of documents in GDoc.

## Alternatives

When it comes to technical document, I find that [approach](https://caitiem.com/2020/03/29/design-docs-markdown-and-git/) much more interesting. Some open source projects have adopted a similar workflow ([Kubernetes](https://github.com/kubernetes/enhancements/tree/master/keps), [Go](https://github.com/golang/proposal)).

A new document starts its life as a text file (using what ever markup language your team/company prefers). The document is submitted for review, and the people who need to be consulted are added as reviewers. They can now comment on the document, the author can address them, mark them as resolved. It's clear in which state the document is: it's either in review, committed, or rejected. With this approach you also end up with a clear history, as time moves on you can amend the document by submitting a change, and the change goes through the same process.

New comers will find the document in the repository, and if they want to see the conversation they can open the review associated with the original change. They can also see how the document evolved over time. It's also easy to publish these documents on an internal website, using a static site generator for example.

One of the thing that I think are critical, is that all of that is done using the tools the engineers are already using for their day to day job: a text editor, a version control system, a code review tool.

There's obviously challenges with this approach too:

- **it's more heavy handed**: not every one likes to write in a text editor using a markup language. It can requires some time to learn or get used to the syntax
- **it's harder to integrate schema / visuals**: but having them checked in in the repository also improves the discoverability

It's also true that no all documents suffer the same challenges for discoverability:

- meeting notes are usually linked to meeting invites (however if you were not part of the meeting, you end up with the same challenges to discover them)
- drafts for communications are usually not relevant once the communication has been sent
- interview notes are usually transferred to some tools for HR when the feedback is submitted
