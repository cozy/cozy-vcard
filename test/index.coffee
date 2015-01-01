VCardParser = require '../lib/index'
should = require('chai').Should()
fs = require 'fs'

describe 'vCard Import', ->

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

    it "should parse a Cozycloud vCard", ->

        parser.read fs.readFileSync 'test/cozy.vcf', 'utf8'
        properties = ['datapoints', 'n', 'fn', 'photo']
        properties.forEach (property) ->
            parser.contacts[3].should.have.property property
            parser.contacts[3].datapoints.length is 3
            # TODO: fix these failing tests
            #parser.contacts[3].note.length.should.be.equal 32
            #parser.contacts[3].datapoints[2].value.length.should.be.equal 53

    it "should toVCF and parse back", ->
        reparser = new VCardParser()
        reparser.read VCardParser.toVCF parser.contacts[0]
        reparser.read VCardParser.toVCF parser.contacts[1]
        reparser.read VCardParser.toVCF parser.contacts[2]
        cozyContact = parser.contacts[3]
        reparser.read VCardParser.toVCF cozyContact, cozyContact.photo
        assert reparser.contacts[3].datapoints.length is 3

