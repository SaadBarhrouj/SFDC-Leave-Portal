import csv

input_file = "countries.csv"
output_file = "App_Countries.globalValueSet-meta.xml"

with open(input_file, mode='r', encoding='utf-8') as csvfile:
    reader = csv.DictReader(csvfile)
    rows = list(reader)

with open(output_file, mode='w', encoding='utf-8') as xmlfile:
    xmlfile.write('<?xml version="1.0" encoding="UTF-8"?>\n')
    xmlfile.write('<GlobalValueSet xmlns="http://soap.sforce.com/2006/04/metadata">\n')

    count = 0
    for row in rows:
        name = row["Name"].strip()
        code = row["Code"].strip()
        xmlfile.write(f'''    <customValue>
        <fullName>{code}</fullName>
        <default>false</default>
        <label>{name}</label>
    </customValue>\n''')
        count += 1

    xmlfile.write('    <masterLabel>App Countries</masterLabel>\n')
    xmlfile.write('    <sorted>true</sorted>\n')
    xmlfile.write('</GlobalValueSet>\n')

print(f"✅ {output_file} généré avec succès avec {count} pays écrits.")
