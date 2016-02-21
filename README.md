# Gerritfs

This gem allows to mount a gerrit as a filesystem. It aims to improve UX to operate reviews.

Usage
-----

```
mkdir /tmp/gerrit
bin/mount /tmp/gerrit gerrit.yml
```

where gerrit.yml contains:

```
base_url: http://gerrit.mydomain
username: a.username
password: my_gerrit_http_password # see your preference
```

Tree mapping (intent, most of it not implemented yet)
------------

- **/my** contains a list of reviews grouped by projects and a file named **dashboard**
 - **/my/dashboard** contains a small recap of all reviews with their status (score, verified)
 - **/my/[group]/[project]/** contains a folder per review
- **/projects** contains one subdir per group containing one subdir per project
 - **/projects/[group]/[project]/** contains a clone of the project allowing easy browsing

A review directory contains:
- **_INFO**: all metadata linked to the review (author, reviewers, scores)
- all patched files (including the commit message, named commit). Content of those file is not clear yet.
  The diff can be seen by opening the hidden files with the basename prefixed by `.a_` and `.b_`. See alias section.
- **_DISCUSSION**: a summary of the discussion so far
- **_REVIEW.tmp**: a temporary file listing all comments not published so far

Moving \_REVIEW.tmp to REVIEW should publish the comments to gerrit.

Patched files are in diff format (with some context). Comments are prefixed by @[author]. Opening a new line, will create a new comment on the line above.

Of course this interface is going to change before being stabilized.


Aliases
-------

To see the diff of a file in a review, you can use the following function:
```
review() {
  for f in $@; do
    dir=$(dirname $f)
    name=$(basename $f)
    echo Reviewing $name
    vimdiff $dir/.a_$name $idr/.b_$name
  done
}
```
