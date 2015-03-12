cozy-vcard
=========

[![Build
Status](https://travis-ci.org/cozy/cozy-vcard.png?branch=master)](https://travis-ci.org/cozy/cozy-vcard)

## Description

*cozy-vcard* is a simple library to deal with the vcard format. It makes life
easier to parse vcard files.

## Usage

```javascript
    # Import

    var vcf = fs.readFileSync('test/friend.vcf', 'utf8');
    var vparser = new VCardParser(vcf);
    var vcontact = parser.components[0];
    var vsomeprop = contact.properties[0]:
    // vcontact.org == 'SuperCorp'
    // someprop.value == '+33123456789'
    // someprop.name == 'tel'
    // someprop.type == 'home'
    // someprop.pref == true


    # Export
    var vcfString = VCardParser.toVCF(vcontact);
    var vcf = fs.writeFileSync('test/friend-export.vcf', vcfString, 'utf8');
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
