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
var vcontact = vparser.contacts[0];
var vsomeprop = vcontact.datapoints[0]:
// vcontact.org == 'SuperCorp'
// vsomeprop.value == '+33123456789'
// vsomeprop.name == 'tel'
// vsomeprop.type == 'home'
// vsomeprop.pref == true


# Export
var vcfString = VCardParser.toVCF(vcontact);
var vcf = fs.writeFileSync('test/friend-export.vcf', vcfString, 'utf8');
```

## Format

This vCard importer doesn't try to follow the official RFC. It is just made to
handle properly vCards from major vendors: Google, Android, iOS, OSX and
thunderbird.

The vCard exporter follow the Google way to write vcards. It can take an option
to export the data to Android format or iOS format

#### How data are handled in memory

Data are stored as direct fields when vendors provide them that way. If not
they are handled as "datapoints". One data datapoint has three fields:

* `name`: the category of the data
* `type`: the label of the field
* `value`: the value of the field


## TODO

If you want to contribute, here is a non-exhaustive list of things to do to
make this project perfect!

Export: 

* manage properly the `pref` attribute.
* manage properly custom types (currently they are often exported uppercased).

Tests: 

* Make full tests field values totally agnostic. 
* Test all fields of full vCards during import and export.

Handle other vendors:

* Thunderbird plugins
* Outlook
* FullContact


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
