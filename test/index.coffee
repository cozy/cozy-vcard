VCardParser = require '../lib/index'
should = require('chai').Should()
expect = require('chai').expect
fs = require 'fs'

describe 'Parsing tools unit tests', ->
    itShouldreturnString = (func) ->
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



describe 'vCard Import', ->

    describe 'contact 0', ->
        parser = new VCardParser()
        it "should parse a google vCard", ->

            parser.read fs.readFileSync 'test/google.vcf', 'utf8'
            properties = ['datapoints', 'n', 'fn', 'org', 'title', 'note']
            properties.forEach (property) ->
                parser.contacts[0].should.have.property property

        it "should parse a apple vCard", ->

            parser.read fs.readFileSync 'test/apple.vcf', 'utf8'
            properties = ['datapoints', 'n', 'fn', 'org', 'title', 'note', 'bday']
            properties.forEach (property) ->
                parser.contacts[1].should.have.property property

        it "should parse an Android vCard", ->

            parser.read fs.readFileSync 'test/android.vcf', 'utf8'
            properties = ['datapoints', 'n', 'fn', 'org', 'title', 'note']
            properties.forEach (property) ->
                parser.contacts[2].should.have.property property

        it "should parse an Android with quoted-printable text vCard", ->

            parser.read fs.readFileSync 'test/android-quotedprintable.vcf', 'utf8'
            properties = ['datapoints', 'n', 'fn', 'org', 'title', 'note']
            properties.forEach (property) ->
                parser.contacts[3].should.have.property property

        it "should parse a Cozycloud vCard", ->

            parser.read fs.readFileSync 'test/cozy.vcf', 'utf8'
            properties = ['datapoints', 'n', 'fn', 'photo']
            properties.forEach (property) ->
                parser.contacts[4].should.have.property property
                parser.contacts[4].datapoints.length is 3
                # TODO: fix these failing tests
                #parser.contacts[3].note.length.should.be.equal 32
                #parser.contacts[3].datapoints[2].value.length.should.be.equal 53

        it "should toVCF and parse back", ->
            reparser = new VCardParser()
            reparser.read VCardParser.toVCF parser.contacts[0]
            reparser.read VCardParser.toVCF parser.contacts[1]
            reparser.read VCardParser.toVCF parser.contacts[2]
            reparser.read VCardParser.toVCF parser.contacts[3]
            cozyContact = parser.contacts[4]
            reparser.read VCardParser.toVCF cozyContact, cozyContact.photo
            reparser.contacts[4].datapoints.length.should.be.equal 3

    describe 'contact A', ->
        parser = new VCardParser()

        datapoints2Flat = (datapoints) ->
            flat = {}
            datapoints.forEach (dp) ->
                flat[dp.name + '_' + dp.type] = dp.value
            return flat

        shouldEqualNoSpaceNorMinus = (obtained, expected) ->
            expected = expected.replace /[-\s]/g, ''
            obtained = obtained.replace /[-\s]/g, ''
            obtained.should.equal expected

        contactsEquals = (obtained, expected) ->
            properties = ['n', 'fn', 'note']
            # properties = ['datapoints', 'n', 'fn', 'org', 'title', 'note']
            properties.forEach (property) ->
                obtained[property].should.equal expected[property]

            datapointsFlat = datapoints2Flat obtained.datapoints

            # datapoints which require tolerance
            for prop in ['tel_cell', 'tel_work']
                # client may introduce meaningless separators in phone numbers
                shouldEqualNoSpaceNorMinus datapointsFlat[prop],
                                           expected.datapointsFlat[prop]

            for prop in ['adr_home', 'adr_work']
                # datapointsFlat[prop].should.eql expected.datapointsFlat[prop]
                datapointsFlat[prop].should.be.a 'array'


            properties = ['email_work', 'email_home']
            properties.forEach (prop) ->
                datapointsFlat[prop].should.equal expected.datapointsFlat[prop]


        expected = JSON.parse fs.readFileSync 'test/fixtures/contactA/contact.json'
        expected.datapointsFlat = datapoints2Flat expected.datapoints

        it "should parse a cozy vCard", ->
            parser.read fs.readFileSync 'test/fixtures/contactA/cozy.vcf', 'utf8'
            contactsEquals parser.contacts[0], expected

            dps = datapoints2Flat parser.contacts[0].datapoints
            VCardParser.adrArrayToString dps.adr_home
                .should.equal '12, rue René Boulanger\n75010 Paris'
            VCardParser.adrArrayToString dps.adr_work
                .should.equal '4, rue Léon Jouhaux\n75010 Paris'

        it "should parse a google vCard", ->
            parser.read fs.readFileSync 'test/fixtures/contactA/google.vcf', 'utf8'
            contactsEquals parser.contacts[1], expected

            dps = datapoints2Flat parser.contacts[1].datapoints
            VCardParser.adrArrayToString dps.adr_home
                .should.equal '12, rue René Boulanger\n75010 Paris'
            VCardParser.adrArrayToString dps.adr_work
                .should.equal '4, rue Léon Jouhaux\n75010 Paris'

        it "should parse a android vCard", ->
            parser.read fs.readFileSync 'test/fixtures/contactA/android.vcf', 'utf8'
            contactsEquals parser.contacts[2], expected

            dps = datapoints2Flat parser.contacts[2].datapoints
            VCardParser.adrArrayToString dps.adr_home
                .should.equal '12, rue René Boulanger\n75010 Paris'
            VCardParser.adrArrayToString dps.adr_work
                .should.equal '4, rue Léon Jouhaux\n75010 Paris'

        it "should parse a iOS vCard", ->
            parser.read fs.readFileSync 'test/fixtures/contactA/ios.vcf', 'utf8'
            contactsEquals parser.contacts[3], expected

            dps = datapoints2Flat parser.contacts[3].datapoints
            VCardParser.adrArrayToString dps.adr_home
                .should.equal '12, rue René Boulanger\nParis, 75010, France'
            VCardParser.adrArrayToString dps.adr_work
                .should.equal '4, rue Léon Jouhaux\nParis, 75010, France'

        it "should parse a thundersync (thunderbird) vCard", ->
            parser.read fs.readFileSync 'test/fixtures/contactA/thundersync.vcf', 'utf8'
            obtained = parser.contacts[4]
            for prop in ['n', 'fn']
                obtained[prop].should.equal expected[prop]

            dps = datapoints2Flat obtained.datapoints

            dps['email_internet'].should.equal expected.datapointsFlat['email_home']


            shouldEqualNoSpaceNorMinus dps['tel_cell'],
                                           expected.datapointsFlat['tel_cell']
            shouldEqualNoSpaceNorMinus dps['tel_work'],
                                           expected.datapointsFlat['tel_work']

            VCardParser.adrArrayToString dps.adr_home
                .should.equal '12, rue René Boulanger\nParis, 75010, France'
            VCardParser.adrArrayToString dps.adr_work
                .should.equal '4, rue Léon Jouhaux\nParis, 75010, France'

        # it "should toVCF and parse back", ->
        #     reparser = new VCardParser()
        #     reparser.read VCardParser.toVCF parser.contacts[0]
        #     reparser.read VCardParser.toVCF parser.contacts[1]
        #     reparser.read VCardParser.toVCF parser.contacts[2]
        #     # reparser.read VCardParser.toVCF parser.contacts[3]
        #     cozyContact = parser.contacts[4]
        #     reparser.read VCardParser.toVCF cozyContact, cozyContact.photo
        #     reparser.contacts[4].datapoints.length.should.be.equal 3


describe 'Contact instances tools', ->
    describe 'nToFN', ->
        it 'should always return a string', ->
            [undefined, null, [],
                ['Lastname', 'Firstname', 'MiddleName', 'Prefix', 'Suffix']].forEach (s) ->
                VCardParser.nToFN s
                    .should.be.a 'string'

        it 'should join in a defined order', ->
            VCardParser.nToFN ['Lastname','Firstname','MiddleName','Prefix','Suffix']
                .should.equal 'Prefix Firstname MiddleName Lastname Suffix'

    describe 'fnToN', ->
        it 'should always return a Array[5]', ->
            [undefined, null, '', 'full name'].forEach (s) ->
                n = VCardParser.fnToN s
                n.should.be.a 'Array'
                n.should.have.length '5'

        it 'should put value as firstname', ->
            VCardParser.fnToN 'full name'
                .should.eql ['', 'full name', '', '', '']

    describe 'adrArrayToString', ->
        it 'should always return a string', ->
            [undefined, null, [],
                ["", "", "4, rue Léon Jouhaux", "Paris", "", "75010", "France"]
            ].forEach (s) ->
                VCardParser.adrArrayToString s
                    .should.be.a 'string'
        it 'should serialise on two lines', ->
            VCardParser.adrArrayToString    ["", "",
                "4, rue Léon Jouhaux", "Paris", "", "75010", "France"]
                    .should.equal '4, rue Léon Jouhaux\nParis, 75010, France'
    describe 'adrStringToArray', ->
         it 'should always return a Array[7]', ->
            [undefined, null, '',
                '12, rue René Boulanger\n75010 Paris'
            ].forEach (s) ->
                n = VCardParser.adrStringToArray s
                n.should.be.a 'Array'
                n.should.have.length '7'

        it 'should put string in street address field', ->
            VCardParser.adrStringToArray '12, rue René Boulanger\n75010 Paris'
                .should.eql ['', '',
                    '12, rue René Boulanger\n75010 Paris',
                    '', '', '', '']


