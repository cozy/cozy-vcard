fs = require 'fs'

data = fs.readFileSync './ios-full.vcf'
data = data.toString()
dataArray = data.split '\n'

fs.writeFileSync './test/bigimport.vcf', ''
for i in [1..5000]
    dataArray[3] = "N:Contact#{i};Full;Middle;Dr.;Suffix"
    dataArray[4] = "FN:Dr. Full Middle Contact#{i} Suffix"
    fs.appendFileSync './bigimport.vcf', dataArray.join '\n'

