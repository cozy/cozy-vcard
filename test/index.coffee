fs = require 'fs'
_ = require 'underscore'
should = require('chai').Should()
expect = require('chai').expect

VCardParser = require '../lib/index'


describe 'Parsing tools unit tests', ->

    describe 'unquotePrintable', ->
        it 'should always return a string', ->
            [undefined, null, '', '=54=65=73=74=C3=A9'].forEach (s) ->
                VCardParser.unquotePrintable(s).should.be.a 'string'

        it 'should convert quoted-printable to plain text', ->
            obtained = VCardParser.unquotePrintable "=54=65=73=74=C3=A9"
            obtained.should.equal "Testé"

    describe 'escapeText', ->
        it 'should know how to be forgotten', ->
            [undefined, null, '', 'test'].forEach (s) ->
                expect VCardParser.escapeText s
                    .to.equal s

        it 'should escape \\n , et ;', ->
            VCardParser.escapeText 'test,\n;'
                .should.equal 'test\\,\\n\\;'

    describe 'unescapeText', ->
        it 'should know how to be forgotten', ->
            [undefined, null, '', 'test'].forEach (s) ->
                expect VCardParser.unescapeText s
                    .to.equal s

        it 'should unescapeText \,\n\\;', ->
            VCardParser.unescapeText 'test\\,\\n\\;'
                .should.equal 'test,\n;'

        it 'should compose to identity with escapeText', ->
            VCardParser.unescapeText VCardParser.escapeText 'test,\n;'
                .should.equal 'test,\n;'


describe 'Contact instances tools', ->
    describe 'nToFN', ->

        it 'should always return a string', ->
            name = ['Lastname', 'Firstname', 'MiddleName', 'Prefix', 'Suffix']
            [undefined, null, [], name].forEach (string) ->
                VCardParser.nToFN(string).should.be.a 'string'

        it 'should join in a defined order', ->
            nameTable = [
                'Lastname', 'Firstname', 'MiddleName', 'Prefix', 'Suffix'
            ]
            expectedName = 'Prefix Firstname MiddleName Lastname Suffix'
            VCardParser.nToFN(nameTable).should.equal expectedName

    describe 'fnToN', ->
        it 'should always return a Array[5]', ->
            values = [undefined, null, '', 'full name']
            values.forEach (string) ->
                name = VCardParser.fnToN string
                name.should.be.a 'Array'
                name.should.have.length '5'

        it 'should put value as firstname', ->
            VCardParser.fnToN('full name').should.eql [
                '', 'full name', '', '', ''
            ]

    describe 'adrArrayToString', ->
        it 'should always return a string', ->
            [
                undefined, null, [],
                ["", "", "4, rue Léon Jouhaux", "Paris", "", "75010", "France"]
            ].forEach (string) ->
                VCardParser.adrArrayToString(string).should.be.a 'string'
        it 'should serialise on two lines', ->
            values = [
                "", "",
                "4, rue Léon Jouhaux", "Paris", "", "75010", "France"]
            VCardParser.adrArrayToString(values)
                    .should.equal '4, rue Léon Jouhaux\nParis, 75010, France'

    describe 'adrStringToArray', ->
         it 'should always return a Array[7]', ->
            [
                undefined, null, '', '12, rue René Boulanger\n75010 Paris'
            ].forEach (string) ->
                name = VCardParser.adrStringToArray string
                name.should.be.a 'Array'
                name.should.have.length '7'

        it 'should put string in street address field', ->
            address = '12, rue René Boulanger\n75010 Paris'
            VCardParser.adrStringToArray(address).should.eql [
                '', '',
                '12, rue René Boulanger\n75010 Paris',
                '', '', '', ''
            ]


describe 'vCard Import', ->

    describe 'Vendor VCards - simple set', ->
        parser = new VCardParser()

        it "Google", ->
            parser.read fs.readFileSync 'test/google.vcf', 'utf8'
            properties = ['datapoints', 'n', 'fn', 'org', 'title', 'note']
            properties.forEach (property) ->
                parser.contacts[0].should.have.property property

        it "Applie", ->
            parser.read fs.readFileSync 'test/apple.vcf', 'utf8'
            properties = ['datapoints', 'n', 'fn', 'org', 'title', 'note', 'bday']
            properties.forEach (property) ->
                parser.contacts[1].should.have.property property

        it "Android", ->
            parser.read fs.readFileSync 'test/android.vcf', 'utf8'
            properties = ['datapoints', 'n', 'fn', 'org', 'title', 'note']
            properties.forEach (property) ->
                parser.contacts[2].should.have.property property

        it "Android with quoted-printable text", ->
            filePath = 'test/android-quotedprintable.vcf'
            parser.read fs.readFileSync filePath, 'utf8'
            properties = ['datapoints', 'n', 'fn', 'org', 'title', 'note']
            properties.forEach (property) ->
                parser.contacts[3].should.have.property property

        it "Cozycloud", ->
            parser.read fs.readFileSync 'test/cozy.vcf', 'utf8'
            properties = ['datapoints', 'n', 'fn', 'photo']
            properties.forEach (property) ->
                parser.contacts[4].should.have.property property
                parser.contacts[4].datapoints.length is 3

        it "Export and import", ->
            reparser = new VCardParser()
            reparser.read VCardParser.toVCF parser.contacts[0], null, false
            reparser.read VCardParser.toVCF parser.contacts[1], null, false
            reparser.read VCardParser.toVCF parser.contacts[2], null, false
            reparser.read VCardParser.toVCF parser.contacts[3], null, false

            cozyContact = parser.contacts[4]
            reparser.read VCardParser.toVCF(
                cozyContact, cozyContact.photo, false)
            reparser.contacts[4].datapoints.length.should.be.equal 3


    describe 'Vendor vCards - complex set', ->
        parser = new VCardParser()

        datapoints2Flat = (datapoints) ->
            flat = {}
            datapoints.forEach (dp) ->
                flat[dp.name + '_' + dp.type] = dp.value
            return flat

        fuzzyEqual = (obtained, expected) ->
            expected = expected.replace /[-\s]/g, ''
            obtained = obtained.replace /[-\s]/g, ''
            obtained.should.equal expected

        checkGroups = (obtained, expected) ->
            hasTags = obtained.tags?
            hasTags.should.be.true

            if hasTags
                obtained.tags.should.deep.equal expected.tags

        contactsEquals = (obtained, expected) ->
            properties = ['n', 'fn', 'note']
            properties.forEach (property) ->
                obtained[property].should.equal expected[property]

            datapointsFlat = datapoints2Flat obtained.datapoints

            # telelphone datapoints require tolerance
            for prop in ['tel_cell', 'tel_work']
                # client may introduce meaningless separators in phone numbers
                fuzzyEqual(
                    datapointsFlat[prop], expected.datapointsFlat[prop])

            properties = ['email_work', 'email_home']
            properties.forEach (prop) ->
                datapointsFlat[prop].should.equal expected.datapointsFlat[prop]

            datapointsFlat.adr_home.should.be.a 'array'
            adrHomeFlat = VCardParser.adrArrayToString datapointsFlat.adr_home

            pass = \
                adrHomeFlat is '12, rue René Boulanger\nParis, 75010, France' or
                adrHomeFlat is '12, rue René Boulanger\n75010 Paris' or
                adrHomeFlat is '12\, rue René Boulanger\, 75010 Paris'
            pass.should.be.true

            datapointsFlat.adr_work.should.be.a 'array'
            adrWorkFlat = VCardParser.adrArrayToString datapointsFlat.adr_work
            pass = \
                adrWorkFlat is '4, rue Léon Jouhaux\nParis, 75010, France' or
                adrWorkFlat is '4, rue Léon Jouhaux\n75010 Paris' or
                adrWorkFlat is '4\, rue Léon Jouhaux\, 75010 Paris'
            pass.should.be.true

        filePath = 'test/fixtures/contactA/contact.json'
        expected = JSON.parse fs.readFileSync filePath
        expected.datapointsFlat = datapoints2Flat expected.datapoints

        it "Cozy", ->
            filePath = 'test/fixtures/contactA/cozy.vcf'
            parser.read fs.readFileSync filePath, 'utf8'
            contactsEquals parser.contacts[0], expected
            checkGroups parser.contacts[0], expected

        it "Google", ->
            filePath = 'test/fixtures/contactA/google.vcf'
            parser.read fs.readFileSync filePath, 'utf8'
            contactsEquals parser.contacts[1], expected

        it "Android", ->
            filePath = 'test/fixtures/contactA/android.vcf'
            parser.read fs.readFileSync filePath, 'utf8'
            contactsEquals parser.contacts[2], expected

        it "iOS", ->
            filePath = 'test/fixtures/contactA/ios.vcf'
            parser.read fs.readFileSync filePath, 'utf8'
            contactsEquals parser.contacts[3], expected

        it "Thundersync (thunderbird)", ->
            filePath = 'test/fixtures/contactA/thundersync.vcf'
            parser.read fs.readFileSync filePath, 'utf8'
            obtained = parser.contacts[4]
            obtained[prop].should.equal expected[prop] for prop in ['n', 'fn']

            dps = datapoints2Flat obtained.datapoints

            expectedEmail = expected.datapointsFlat['email_home']
            dps['email_internet'].should.equal expectedEmail

            fuzzyEqual dps['tel_cell'], expected.datapointsFlat['tel_cell']
            fuzzyEqual dps['tel_work'], expected.datapointsFlat['tel_work']

            VCardParser.adrArrayToString dps.adr_home
                .should.equal '12, rue René Boulanger\nParis, 75010, France'
            VCardParser.adrArrayToString dps.adr_work
                .should.equal '4, rue Léon Jouhaux\nParis, 75010, France'

        it "Sogo (thunderbird)", ->
            filePath = 'test/fixtures/contactA/sogo.vcf'
            parser.read fs.readFileSync filePath, 'utf8'
            contactsEquals parser.contacts[5], expected
            checkGroups parser.contacts[5], expected

        it "DAVdroid (Android)", ->
            filePath = 'test/fixtures/contactA/davdroid.vcf'
            parser.read fs.readFileSync filePath, 'utf8'
            contactsEquals parser.contacts[6], expected
            checkGroups parser.contacts[6], expected

        it "iOS", ->
            filePath = 'test/fixtures/contactA/ios_fromcozysync.vcf'
            parser.read fs.readFileSync filePath, 'utf8'
            contactsEquals parser.contacts[7], expected
            checkGroups parser.contacts[7], expected

        it "Sogo (thunderbird) from a sync with Cozy vCard", ->
            filePath = 'test/fixtures/contactA/sogo_fromcozysync.vcf'
            parser.read fs.readFileSync filePath, 'utf8'
            contactsEquals parser.contacts[8], expected
            checkGroups parser.contacts[8], expected

        it "Export then import", ->
            reparser = new VCardParser()
            reparser.read VCardParser.toVCF parser.contacts[0], null, false
            reparser.read VCardParser.toVCF parser.contacts[1], null, false
            reparser.read VCardParser.toVCF parser.contacts[2], null, false
            reparser.read VCardParser.toVCF parser.contacts[3], null, false
            reparser.read VCardParser.toVCF parser.contacts[5], null, false
            reparser.read VCardParser.toVCF parser.contacts[6], null, false
            reparser.read VCardParser.toVCF parser.contacts[7], null, false
            reparser.read VCardParser.toVCF parser.contacts[8], null, false

            reparser.contacts.forEach (obtained) ->
                contactsEquals obtained, expected


describe 'Full contact vcard (tricky fields)', ->

    describe 'Google Contacts vcard should retrieve', ->
        parser = new VCardParser()
        parser.read fs.readFileSync 'test/google-full.vcf', 'utf8'
        contact = parser.contacts[0]
        datapoints = contact.datapoints

        it "bday", ->
            contact.bday.should.equal '1961-04-05'
        it "org", ->
            contact.org.should.equal 'SuperCorp'
        it "title", ->
            contact.title.should.equal 'Chairman'

        it "typed url", ->
            urls = _.filter datapoints, (point) ->
                point.name is 'url'
            urls.length.should.equal 5
            urls[0].type.should.equal 'profile'
            urls[0].value.should.equal 'http://profile.example.com/'
            urls[2].type.should.equal 'homepage'
            urls[2].value.should.equal 'http://home.example.com/'
            urls[4].type.should.equal 'arbitrarystring'
            urls[4].value.should.equal 'http://custom.example.com/'

        it "instant messaging accounts", ->
            ims = _.filter datapoints, (point) ->
                point.name is 'chat'
            ims.length.should.equal 8
            ims[0].type.should.equal 'aim'
            ims[0].value.should.equal 'AIM'

        it "tel composed of several names", ->
            workfax = _.filter datapoints, (point) ->
                point.type is 'work fax'
            workfax.length.should.equal 1
            homefax = _.filter datapoints, (point) ->
                point.type is 'home fax'
            homefax.length.should.equal 1

        it  "relations", ->
            relations = _.filter datapoints, (point) ->
                point.name is 'relation'
            relations.length.should.equal 15
            relations[0].type.should.equal 'spouse'
            relations[0].value.should.equal 'Spouse'


    describe 'Android vcard should retrieve', ->
        parser = new VCardParser()
        parser.read fs.readFileSync 'test/android-full.vcf', 'utf8'
        contact = parser.contacts[0]
        datapoints = contact.datapoints

        it "bday", ->
            contact.bday.should.equal '2015-03-03'
        it "org", ->
            contact.org.should.equal 'SuperCorp'
        it "tile", ->
            contact.title.should.equal 'Chairman'
        it "url", ->
            contact.url.should.equal 'http://cozy.io'
        it "nickname", ->
            contact.nickname.should.equal 'Pseudo'

        it "instant messaging accounts", ->
            ims = _.filter datapoints, (point) ->
                point.name is 'chat'
            ims.length.should.equal 9
            ims[0].type.should.equal 'skype-username'
            ims[0].value.should.equal 'skypeaccount'

        it "phonetic fields", ->
            fields = _.filter datapoints, (point) ->
                point.name is 'about' and point.type.indexOf('phonetic') is 0
            fields.length.should.equal 3
            fields[0].type.should.equal 'phonetic first name'
            fields[0].value.should.equal 'Jon'

        it "tel composed of several names", ->
            workfax = _.filter datapoints, (point) ->
                point.type is 'work cell'
            workfax.length.should.equal 1
            homefax = _.filter datapoints, (point) ->
                point.type is 'work pager'
            homefax.length.should.equal 1

        it "relations", ->
            relations = _.filter datapoints, (point) ->
                point.name is 'relation'
            relations.length.should.equal 14
            relations[0].type.should.equal 'assistant'
            relations[0].value.should.equal 'Assistant'


    describe 'Export', ->
        parser = new VCardParser()
        parser.read fs.readFileSync 'test/google-full.vcf', 'utf8'
        contact = parser.contacts[0]
        contact.nickname = "Nickname"

        vcf = VCardParser.toVCF(contact).split('\n')
        console.log vcf.join('\n')

        it "org", ->
            test = "ORG:SuperCorp" in vcf
            test.should.be.ok

        it "bday", ->
            test = "BDAY:1961-04-05" in vcf
            test.should.be.ok

        it "title", ->
            test = "TITLE:Chairman" in vcf
            test.should.be.ok

        it "tel composed of several names", ->
            test = "TEL;TYPE=WORK;TYPE=FAX:+1 212 555 2345" in vcf
            test.should.be.ok

        it "relations", ->
            test = "item17.X-ABRELATEDNAMES:Big Boss" in vcf
            test.should.be.ok
            test = "item17.X-ABLabel:_$!<Manager>!$_" in vcf
            test.should.be.ok
            test = "X-ANDROID-CUSTOM:vnd.android.cursor.item/relation;Big Boss;7;;;;;;;;;;;;;" in vcf
            test.should.be.ok

        it "url", ->
            test = "item2.URL:http://blog.example.com/" in vcf
            test.should.be.ok
            test = "item2.X-ABLabel:BLOG" in vcf
            test.should.be.ok

        it "skype", ->
            test = "X-SKYPE-USERNAME:Skype" in vcf
            test.should.be.ok
            test = "X-SKYPE:Skype" in vcf
            test.should.be.ok

        it.skip "died", ->
        it.skip "anniversary", ->

        it.skip "nickname", ->
        it.skip "phonetic fields", ->

