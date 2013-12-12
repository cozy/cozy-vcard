VCardParser = require '../lib/index'
should = require('chai').Should()
fs = require 'fs'

describe 'vCard Import', ->

    parser = new VCardParser()

    it "should parse a google vCard", ->

        parser.read fs.readFileSync 'test/google.vcf', 'utf8'
        # vcf.should.equal VCardParser.toVCF parser.contacts[0]

    it "should parse a apple vCard", ->

        parser.read fs.readFileSync 'test/apple.vcf', 'utf8'
        # vcf.should.equal VCardParser.toVCF parser.contacts[0]

    it "should parse an Android vCard", ->

        parser.read fs.readFileSync 'test/android.vcf', 'utf8'
        # vcf.should.equal VCardParser.toVCF parser.contacts[0]


    it "should toVCF and parse back", ->
        reparser = new VCardParser()
        reparser.read VCardParser.toVCF parser.contacts[0]
        reparser.read VCardParser.toVCF parser.contacts[1]
        reparser.read VCardParser.toVCF parser.contacts[2]


        # console.log parser.contacts[0]
