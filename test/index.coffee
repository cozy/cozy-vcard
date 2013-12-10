VCardParser = require '../lib/index'
should = require 'should'
fs = require 'fs'

describe 'vCard Import', ->

    it "should parse a google vCard", ->

        vcf = fs.readFileSync 'test/google.vcf', 'utf8'
        parser = new VCardParser()
        parser.read vcf
        # console.log parser.contacts[0].datapoints

    it "should parse a apple vCard", ->

        vcf = fs.readFileSync 'test/apple.vcf', 'utf8'
        parser = new VCardParser()
        parser.read vcf
        # console.log parser.contacts[0].datapoints

    it "should parse an Android vCard", ->

        vcf = fs.readFileSync 'test/android.vcf', 'utf8'
        parser = new VCardParser()
        parser.read vcf
        # console.log parser.contacts[0].datapoints
