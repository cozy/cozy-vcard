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
            [undefined, null, '', 'test'].forEach (value) ->
                expect(VCardParser.escapeText(value)).to.equal value

        it 'should escape \\n , et ;', ->
            VCardParser.escapeText 'test,\n;'
                .should.equal 'test\\,\\n\\;'

    describe 'unescapeText', ->
        it 'should know how to be forgotten', ->
            [undefined, null, '', 'test'].forEach (value) ->
                expect(VCardParser.unescapeText(value)).to.equal value

        it 'should unescapeText ,\\n\\;', ->
            VCardParser.unescapeText('test\\,\\n\\;').should.equal 'test,\n;'

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
        parser = null
        beforeEach ->
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
                parser.contacts[0].should.have.property property

        it "iOS", ->
            parser.read fs.readFileSync 'test/ios-imported-contact.vcf', 'utf8'
            properties = ['datapoints', 'n', 'fn', 'photo', 'tags']
            properties.forEach (property) ->
                parser.contacts[0].should.have.property property

        it "Android", ->
            parser.read fs.readFileSync 'test/android.vcf', 'utf8'
            properties = ['datapoints', 'n', 'fn', 'org', 'title', 'note']
            properties.forEach (property) ->
                parser.contacts[0].should.have.property property

        it "Android with quoted-printable text", ->
            filePath = 'test/android-quotedprintable.vcf'
            parser.read fs.readFileSync filePath, 'utf8'
            properties = ['datapoints', 'n', 'fn', 'org', 'title', 'note']
            properties.forEach (property) ->
                parser.contacts[0].should.have.property property

        it "Cozycloud", ->
            parser.read fs.readFileSync 'test/cozy.vcf', 'utf8'
            properties = ['datapoints', 'n', 'fn', 'photo']
            properties.forEach (property) ->
                parser.contacts[0].should.have.property property
                parser.contacts[0].datapoints.length is 3

        it "Export and import", ->
            parser.read fs.readFileSync 'test/google.vcf', 'utf8'
            parser.read fs.readFileSync 'test/apple.vcf', 'utf8'
            parser.read fs.readFileSync 'test/android.vcf', 'utf8'
            parser.read fs.readFileSync 'test/ios-imported-contact.vcf', 'utf8'
            parser.read fs.readFileSync 'test/cozy.vcf', 'utf8'

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

        checkExtraProperties = (obtained, expected) ->
          
            properties = ['tz', 'lang', 'geo', 'gender', 'kind']
            properties.forEach (property) ->
                obtained[property].should.equal expected[property]

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

            if datapointsFlat['adr_home fr']?
                datapointsFlat.adr_home = datapointsFlat['adr_home fr']
            datapointsFlat.adr_home.should.be.a 'array'
            adrHomeFlat = VCardParser.adrArrayToString datapointsFlat.adr_home

            pass = \
                adrHomeFlat is '12, rue René Boulanger\nParis, 75010, France' or
                adrHomeFlat is '12, rue René Boulanger\n75010 Paris' or
                adrHomeFlat is '12\, rue René Boulanger\, 75010 Paris'
            pass.should.be.true

            if datapointsFlat['adr_work fr']?
                datapointsFlat.adr_work = datapointsFlat['adr_work fr']
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

        it "Firefox OS", ->
            filePath = 'test/ffos.vcf'
            parser.read fs.readFileSync filePath, 'utf8'
            parser.contacts[9].n.should.equal 'Firefox;Barbara;;;;'
            parser.contacts[9].fn.should.equal 'Barbara Firefox'
            parser.contacts[9].datapoints[0].value.should.equal '+966238347324'
            parser.contacts[9].datapoints[0].type.should.equal 'cell'

        it "Extra-Fields", ->
            filePath = 'test/fixtures/contactA/extra-fields.vcf'
            parser.read fs.readFileSync filePath, 'utf8'
            checkExtraProperties parser.contacts[10], expected

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
        it "title", ->
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


    describe 'iOS vcard should retrieve', ->
        parser = new VCardParser()
        parser.read fs.readFileSync 'test/ios-full.vcf', 'utf8'
        contact = parser.contacts[0]
        datapoints = contact.datapoints

        it "bday", ->
            contact.bday.should.equal '2015-03-03'
        it "org", ->
            contact.org.should.equal 'SuperCorp'
        it "department", ->
            contact.department.should.equal 'Department'
        it "title", ->
            contact.title.should.equal 'Chairman'
        it "nickname", ->
            contact.nickname.should.equal 'Pseudo'

        it "instant messaging accounts", ->
            ims = _.filter datapoints, (point) ->
                point.name is 'chat'
            ims.length.should.equal 16
            ims[0].type.should.equal 'msn'
            ims[0].value.should.equal 'msn'
            ims[10].value.should.equal 'yahoo'
            ims[10].type.should.equal 'yahoo'
            ims[10]['x-service-type'].should.equal 'yahoo'
            ims[15].value.should.equal 'custom%20im'
            ims[15].type.should.equal 'customim'
            ims[15]['x-service-type'].should.equal 'customim'

        it "phonetic name", ->
            abouts = _.filter datapoints, (point) ->
                point.name is 'about'
            abouts.length.should.equal 6
            abouts[0].type.should.equal 'phonetic first name'
            abouts[0].value.should.equal 'Phonetic First Name'
            abouts[1].type.should.equal 'phonetic middle name'
            abouts[1].value.should.equal 'Phonetic Middle Name'
            abouts[2].type.should.equal 'phonetic last name'
            abouts[2].value.should.equal 'Phonetic Last Name'

        it "emails", ->
            emails = _.filter datapoints, (point) ->
                point.name is 'email'
            emails.length.should.equal 6
            emails[0].type.should.equal 'home pref'
            emails[0].value.should.equal 'test@cozy.io'
            emails[4].type.should.equal 'customemail'
            emails[4].value.should.equal 'test5@cozy.io'

        it "tels", ->
            tels = _.filter datapoints, (point) ->
                point.name is 'tel'
            tels[0].type.should.equal 'home voice pref'
            tels[0].value.should.equal '0102030400'
            tels[9].type.should.equal 'customphone'
            tels[9].value.should.equal '0102030409'

        it "address custom", ->
            addrs = _.filter datapoints, (point) ->
                point.name is 'adr'
            addrs.length.should.equal 4
            addrs[3].type.should.equal 'home customaddress fr'
            addrs[3].value[2].should.equal '55\nRue Bonsergent'
            addrs[3].value[3].should.equal '75010'
            addrs[3].value[4].should.equal 'Ile De France'
            addrs[3].value[5].should.equal 'Paris'
            addrs[3].value[6].should.equal 'France'

        it "urls", ->
            urls = _.filter datapoints, (point) ->
                point.name is 'url'
            urls.length.should.equal 5
            urls[0].type.should.equal 'homepage'
            urls[0].value.should.equal 'http://homepage.fr'
            urls[4].type.should.equal 'custom'
            urls[4].value.should.equal 'http://custom.fr'

        it "social profile", ->
            profiles = _.filter datapoints, (point) ->
                point.name is 'social'

            profiles.length.should.be.equal 7
            profiles[0].type.should.equal 'twitter'
            profiles[0].value.should.equal 'twitteruser'
            profiles[6].type.should.equal 'customsocial'
            profiles[6].value.should.equal 'custom socialuser'

        it "anniversary", ->
            abouts = _.filter datapoints, (point) ->
                point.name is 'about'
            abouts.length.should.equal 6
            abouts[3].type.should.equal 'anniversary'
            abouts[3].value.should.equal '2013-03-12'
            abouts[4].type.should.equal 'other'
            abouts[4].value.should.equal '2012-03-12'
            abouts[5].type.should.equal 'customdate'
            abouts[5].value.should.equal '2006-03-12'

        it "relations", ->
            relations = _.filter datapoints, (point) ->
                point.name is 'relation'
            relations.length.should.equal 13
            relations[0].type.should.equal 'mother'
            relations[0].value.should.equal 'Mother'
            relations[12].type.should.equal 'customrelation'
            relations[12].value.should.equal 'Custom Relation'

        it "alerts", ->
            alerts = _.filter datapoints, (point) ->
                point.name is 'alerts'
            alerts.length.should.equal 2
            alerts[0].type.should.equal 'call'
            alerts[0].value.should.equal 'snd=system:Bulletin\\,vib=Alert'

    describe 'Export', ->

        describe 'Google', ->
            parser = new VCardParser()
            parser.read fs.readFileSync 'test/google-full.vcf', 'utf8'
            contact = parser.contacts[0]
            date = new Date().toISOString()
            contact.revision = date

            vcf = VCardParser.toVCF(contact, null, 'google').split('\n')

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
                test = "X-ANDROID-CUSTOM:vnd.android.cursor.item/relation;Big Boss;7;;;;;;;;;;;;;" not in vcf
                test.should.be.ok

            it "url", ->
                test = "item2.URL:http://blog.example.com/" in vcf
                test.should.be.ok
                test = "item2.X-ABLabel:BLOG" in vcf
                test.should.be.ok

            it "skype", ->
                test = "X-SKYPE-USERNAME:Skype" not in vcf
                test.should.be.ok
                test = "X-SKYPE:Skype" in vcf
                test.should.be.ok

            it "rev", ->
                test = "REV:#{date}" in vcf
                test.should.be.ok

            it "died", ->
                test = "item6.X-ABDATE:2014-12-31" in vcf
                test.should.be.ok
                test = "item6.X-ABLabel:Died" in vcf
                test.should.be.ok
                test = 'X-ANDROID-CUSTOM:vnd.android.cursor.item/contact_event;2014-12-31;2;;;;;;;;;;;;;' not in vcf
                test.should.be.ok

            it "anniversary", ->
                test = "item7.X-ABDATE:2001-01-01" in vcf
                test.should.be.ok
                test = "item7.X-ABLabel:Anniversary" in vcf
                test.should.be.ok
                test = 'X-ANDROID-CUSTOM:vnd.android.cursor.item/contact_event;2001-01-01;1;;;;;;;;;;;;;' not in vcf
                test.should.be.ok


        describe 'Android', ->
            parser = new VCardParser()
            parser.read fs.readFileSync 'test/google-full.vcf', 'utf8'
            contact = parser.contacts[0]
            date = new Date().toISOString()
            contact.revision = date

            vcf = VCardParser.toVCF(contact, null, 'android').split('\n')

            it "skype", ->
                test = "X-SKYPE-USERNAME:Skype" in vcf
                test.should.be.ok
                test = "X-SKYPE:Skype" not in vcf
                test.should.be.ok

            it "died", ->
                test = "item6.X-ABDATE:2014-12-31" not in vcf
                test.should.be.ok
                test = "item6.X-ABLabel:Died" not in vcf
                test.should.be.ok
                test = 'X-ANDROID-CUSTOM:vnd.android.cursor.item/contact_event;2014-12-31;2;;;;;;;;;;;;;' in vcf
                test.should.be.ok

            it "anniversary", ->
                test = "item7.X-ABDATE:2001-01-01" not in vcf
                test.should.be.ok
                test = "item7.X-ABLabel:Anniversary" not in vcf
                test.should.be.ok
                test = 'X-ANDROID-CUSTOM:vnd.android.cursor.item/contact_event;2001-01-01;1;;;;;;;;;;;;;' in vcf
                test.should.be.ok

            it "relations", ->
                test = "item17.X-ABRELATEDNAMES:Big Boss" not in vcf
                test.should.be.ok
                test = "item17.X-ABLabel:_$!<Manager>!$_" not in vcf
                test.should.be.ok
                test = "X-ANDROID-CUSTOM:vnd.android.cursor.item/relation;Big Boss;7;;;;;;;;;;;;;" in vcf
                test.should.be.ok



        describe 'iOS', ->
            parser = new VCardParser()
            parser.read fs.readFileSync 'test/ios-full.vcf', 'utf8'
            contact = parser.contacts[0]
            date = new Date().toISOString()
            contact.revision = date

            vcf = VCardParser.toVCF(contact, null, 'ios').split('\n')

            it "department", ->
                test = 'ORG:SuperCorp;Department' in vcf
                test.should.be.ok

            it "nickname", ->
                test = 'NICKNAME:Pseudo' in vcf
                test.should.be.ok

            it "phonetic fields", ->
                test = 'X-PHONETIC-FIRST-NAME:Phonetic First Name' in vcf
                test.should.be.ok
                test = 'X-PHONETIC-MIDDLE-NAME:Phonetic Middle Name' in vcf
                test.should.be.ok
                test = 'X-PHONETIC-LAST-NAME:Phonetic Last Name' in vcf
                test.should.be.ok

            it "social profile", ->
                test = 'X-SOCIALPROFILE;TYPE=TWITTER;x-user=twitteruser:http://twitter.com/twitteruser'
                test.should.be.ok

            it "instant messaging", ->
                test = 'item6.IMPP;X-SERVICE-TYPE=MSN:msnim:msn' in vcf
                test.should.be.ok

            it "dates", ->
                test = 'item22.X-ABDATE:2013-03-12' in vcf
                test.should.be.ok
                test = 'item22.X-ABLabel:Anniversary' in vcf
                test.should.be.ok
                test = 'item23.X-ABDATE:2012-03-12' in vcf
                test.should.be.ok
                test = 'item23.X-ABLabel:Other' in vcf
                test.should.be.ok

            it "notes", ->

            it "custom social", ->
                test = 'X-SOCIALPROFILE;TYPE=Customsocial;x-user=custom socialuser:custom socialuser' in vcf
                test.should.be.ok

            it "custom urls", ->
                test = 'item5.URL:http://custom.fr' in vcf
                test = 'item5.X-ABLabel:Custom' in vcf

            it "custom relations", ->
                test = 'item37.X-ABRELATEDNAMES:Custom Relation' in vcf
                test = 'item37.X-ABLabel:_$!<Customrelation>!$_' in vcf

            it "rev", ->
                test = "REV:#{date}" in vcf
                test.should.be.ok

            it "alerts", ->
                test = 'X-ACTIVITY-ALERT:type=call\\,snd=system:Bulletin\\,vib=Alert' in vcf
                test.should.be.ok
                test = 'X-ACTIVITY-ALERT:type=text\\,snd=<none>'
                test.should.be.ok

describe 'social-profile', ->
    parser = new VCardParser()
    parser.read fs.readFileSync 'test/social.vcf', 'utf8'
    contact = parser.contacts[0]

    it 'should parse all 3 instances of the X-SOCIALPROFILE fields', ->
        contact.datapoints.length.should.be.equal 3

    it 'contact should have 3 valid instances of social datapoints', ->
        contact.datapoints.forEach (datapoint) ->
            datapoint.name.should.be.ok
            datapoint.type.should.be.ok
            datapoint.value.should.be.ok
            datapoint.name.should.equal 'social'
            datapoint.type.should.equal 'facebook'
            datapoint.value.should.equal 'mizrachiran'

describe 'multiple-vcards', ->
    parser = new VCardParser()
    parser.read fs.readFileSync 'test/multiple-cards.vcf', 'utf8'

    it 'should parse 2 vcards successfully', ->
        parser.contacts.length.should.be.equal 2

    it 'first contact should be parse successfully', ->
        contact1 = parser.contacts[0];
        contact1.uid.should.be.ok
        contact1.uid.should.equal '599'
        contact1.fn.should.be.ok
        contact1.fn.should.equal 'Dana Zohar'

    it 'second contact should be parse successfully', ->
        contact2 = parser.contacts[1];
        contact2.uid.should.be.ok
        contact2.uid.should.equal '2733'
        contact2.fn.should.be.ok
        contact2.fn.should.equal 'Daniel'

describe 'non-regressions', ->

    it '(Ref cozy-sync/#78) should not throw on corrupted contact', ->
        contact =
            id: '76273267326372'
            n: 'a;b;c;d;e'
            datapoints: [value: '+123242332323', name: undefined]

        test = ->
            vcf = VCardParser.toVCF(contact, null, 'ios')
        test.should.not.throw()
