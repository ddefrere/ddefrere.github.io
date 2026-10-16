---
layout: page
permalink: /Publications/
title: Publications
description: Peer-reviewed articles and conference proceedings from Denis Defrère’s group and collaborators, with search and BibTeX-backed bibliography.
nav: true
nav_order: 4
---

{% assign metrics = site.data.scholar_metrics %}

<div class="citation-metrics">
  <span><strong>{{ metrics.publications | delimited }}</strong> publications</span>
  <span><strong>{{ metrics.citations | delimited }}</strong> citations</span>
  <span><strong>h-index {{ metrics.h_index }}</strong></span>
  <span class="citation-source">
    <a
      href="https://scholar.google.com/citations?user={{ site.data.socials.scholar_userid }}&hl=en"
      target="_blank"
      rel="noopener noreferrer"
      >Google Scholar</a
    >
  </span>
</div>

<!-- _pages/publications.md -->

<!-- Bibsearch Feature -->

{% include bib_search.liquid %}

<div class="publications">

{% bibliography %}

</div>
