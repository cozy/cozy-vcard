cozy-vcard
=========

[![Build
Status](https://travis-ci.org/mycozycloud/cozy-vcard.png?branch=master)](https://travis-ci.org/mycozycloud/cozy-vcard)

## Description

*cozy-vcard* is a simple library to deal with the vcard format. It makes life
easier to parse vcard files.

## Usage

```javascript
    vcf = fs.readFileSync('test/friend.vcf', 'utf8');
    parser = new VCardParser(vcf);
    contact = parser.components[0];
    someprop = contact.properties[0]:
    // someprop.value == '+33123456789'
    // someprop.name == 'tel'
    // someprop.type == 'home'
    // someprop.pref == true
```

## What is Cozy?

![Cozy Logo](https://raw.github.com/mycozycloud/cozy-setup/gh-pages/assets/images/happycloud.png)

[Cozy](http://cozy.io) is a platform that brings all your web services in the
same private space.  With it, your web apps and your devices can share data
easily, providing you
with a new experience. You can install Cozy on your own hardware where no one
profiles you. You install only the applications you want. You can build your
own one too.

## Community 

You can reach the Cozy community via various support:

* IRC #cozycloud on irc.freenode.net
* Post on our [Forum](https://groups.google.com/forum/?fromgroups#!forum/cozy-cloud)
* Post issues on the [Github repos](https://github.com/mycozycloud/)
* Via [Twitter](http://twitter.com/mycozycloud)
