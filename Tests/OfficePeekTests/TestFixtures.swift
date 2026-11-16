import Foundation

/// 自包含最小 OOXML 测试归档生成器（使用 STORE 模式打包为标准 `.docx` / `.pptx` / `.xlsx`）
enum TestFixtures {

    static func writeMinimalPPTX(to url: URL, slides: [(backgroundHex: String, title: String)]) throws {
        var slideIdNodes = ""
        var presentationRels = """
        <?xml version="1.0" encoding="UTF-8"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
          <Relationship Id="rMaster" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideMaster" Target="slideMasters/slideMaster1.xml"/>
        """
        var contentTypeOverrides = """
        <Override PartName="/ppt/presentation.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.presentation.main+xml"/>
        <Override PartName="/ppt/slideLayouts/slideLayout1.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.slideLayout+xml"/>
        <Override PartName="/ppt/slideMasters/slideMaster1.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.slideMaster+xml"/>
        <Override PartName="/ppt/theme/theme1.xml" ContentType="application/vnd.openxmlformats-officedocument.theme+xml"/>
        """

        var entries: [(String, Data)] = [
            ("_rels/.rels", Data("""
            <?xml version="1.0" encoding="UTF-8"?>
            <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
              <Relationship Id="rOffice" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="ppt/presentation.xml"/>
            </Relationships>
            """.utf8))
        ]

        for (idx, slide) in slides.enumerated() {
            let num = idx + 1
            let rId = "rSlide\(num)"
            let sldId = 256 + idx
            slideIdNodes += "<p:sldId id=\"\(sldId)\" r:id=\"\(rId)\"/>"
            presentationRels += "<Relationship Id=\"\(rId)\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/slide\" Target=\"slides/slide\(num).xml\"/>"
            contentTypeOverrides += "<Override PartName=\"/ppt/slides/slide\(num).xml\" ContentType=\"application/vnd.openxmlformats-officedocument.presentationml.slide+xml\"/>"

            let slideXML = """
            <?xml version="1.0" encoding="UTF-8"?>
            <p:sld xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main"
                   xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main"
                   xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
              <p:cSld>
                <p:bg><p:bgPr><a:solidFill><a:srgbClr val="\(slide.backgroundHex)"/></a:solidFill></p:bgPr></p:bg>
                <p:spTree>
                  <p:nvGrpSpPr><p:cNvPr id="1" name=""/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr>
                  <p:grpSpPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="0" cy="0"/><a:chOff x="0" y="0"/><a:chExt cx="0" cy="0"/></a:xfrm></p:grpSpPr>
                  <p:sp>
                    <p:nvSpPr><p:cNvPr id="2" name="Title"/><p:cNvSpPr txBox="1"/><p:nvPr/></p:nvSpPr>
                    <p:spPr>
                      <a:xfrm><a:off x="914400" y="914400"/><a:ext cx="5486400" cy="1828800"/></a:xfrm>
                      <a:prstGeom prst="rect"><a:avLst/></a:prstGeom>
                      <a:solidFill><a:srgbClr val="112233"/></a:solidFill>
                    </p:spPr>
                    <p:txBody>
                      <a:bodyPr/>
                      <a:lstStyle/>
                      <a:p><a:r><a:rPr lang="en-US" sz="2800"><a:solidFill><a:srgbClr val="FFFFFF"/></a:solidFill></a:rPr><a:t>\(slide.title)</a:t></a:r></a:p>
                    </p:txBody>
                  </p:sp>
                </p:spTree>
              </p:cSld>
              <p:clrMapOvr><a:masterClrMapping/></p:clrMapOvr>
            </p:sld>
            """
            entries.append(("ppt/slides/slide\(num).xml", Data(slideXML.utf8)))
            entries.append(("ppt/slides/_rels/slide\(num).xml.rels", Data("""
            <?xml version="1.0" encoding="UTF-8"?>
            <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
              <Relationship Id="rLayout" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideLayout" Target="../slideLayouts/slideLayout1.xml"/>
            </Relationships>
            """.utf8)))
        }

        presentationRels += "</Relationships>"

        entries.append(("[Content_Types].xml", Data("""
        <?xml version="1.0" encoding="UTF-8"?>
        <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
          <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
          <Default Extension="xml" ContentType="application/xml"/>
          \(contentTypeOverrides)
        </Types>
        """.utf8)))

        entries.append(("ppt/presentation.xml", Data("""
        <?xml version="1.0" encoding="UTF-8"?>
        <p:presentation xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main"
                        xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main"
                        xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
          <p:sldMasterIdLst><p:sldMasterId id="2147483648" r:id="rMaster"/></p:sldMasterIdLst>
          <p:sldIdLst>\(slideIdNodes)</p:sldIdLst>
          <p:sldSz cx="9144000" cy="5143500" type="screen16x9"/>
        </p:presentation>
        """.utf8)))
        entries.append(("ppt/_rels/presentation.xml.rels", Data(presentationRels.utf8)))
        entries.append(("ppt/slideLayouts/slideLayout1.xml", Data("""
        <?xml version="1.0" encoding="UTF-8"?>
        <p:sldLayout xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main"
                     xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" type="blank" preserve="1">
          <p:cSld name="Blank"><p:spTree><p:nvGrpSpPr><p:cNvPr id="1" name=""/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr><p:grpSpPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="0" cy="0"/><a:chOff x="0" y="0"/><a:chExt cx="0" cy="0"/></a:xfrm></p:grpSpPr></p:spTree></p:cSld>
          <p:clrMapOvr><a:masterClrMapping/></p:clrMapOvr>
        </p:sldLayout>
        """.utf8)))
        entries.append(("ppt/slideLayouts/_rels/slideLayout1.xml.rels", Data("""
        <?xml version="1.0" encoding="UTF-8"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
          <Relationship Id="rMaster" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideMaster" Target="../slideMasters/slideMaster1.xml"/>
        </Relationships>
        """.utf8)))
        entries.append(("ppt/slideMasters/slideMaster1.xml", Data("""
        <?xml version="1.0" encoding="UTF-8"?>
        <p:sldMaster xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main"
                     xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main"
                     xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
          <p:cSld name="Master"><p:spTree><p:nvGrpSpPr><p:cNvPr id="1" name=""/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr><p:grpSpPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="0" cy="0"/><a:chOff x="0" y="0"/><a:chExt cx="0" cy="0"/></a:xfrm></p:grpSpPr></p:spTree></p:cSld>
          <p:clrMap accent1="accent1" accent2="accent2" accent3="accent3" accent4="accent4"
                    accent5="accent5" accent6="accent6" bg1="lt1" bg2="lt2" tx1="dk1" tx2="dk2" hlink="hlink" folHlink="folHlink"/>
          <p:sldLayoutIdLst><p:sldLayoutId id="2147483649" r:id="rLayout"/></p:sldLayoutIdLst>
          <p:txStyles><p:titleStyle/><p:bodyStyle/><p:otherStyle/></p:txStyles>
        </p:sldMaster>
        """.utf8)))
        entries.append(("ppt/slideMasters/_rels/slideMaster1.xml.rels", Data("""
        <?xml version="1.0" encoding="UTF-8"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
          <Relationship Id="rLayout" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideLayout" Target="../slideLayouts/slideLayout1.xml"/>
          <Relationship Id="rTheme" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/theme" Target="../theme/theme1.xml"/>
        </Relationships>
        """.utf8)))
        entries.append(("ppt/theme/theme1.xml", Data("""
        <?xml version="1.0" encoding="UTF-8"?>
        <a:theme xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" name="Office">
          <a:themeElements>
            <a:clrScheme name="Office">
              <a:dk1><a:srgbClr val="000000"/></a:dk1><a:lt1><a:srgbClr val="FFFFFF"/></a:lt1>
              <a:dk2><a:srgbClr val="1F497D"/></a:dk2><a:lt2><a:srgbClr val="EEECE1"/></a:lt2>
              <a:accent1><a:srgbClr val="4F81BD"/></a:accent1><a:accent2><a:srgbClr val="C0504D"/></a:accent2>
              <a:accent3><a:srgbClr val="9BBB59"/></a:accent3><a:accent4><a:srgbClr val="8064A2"/></a:accent4>
              <a:accent5><a:srgbClr val="4BACC6"/></a:accent5><a:accent6><a:srgbClr val="F79646"/></a:accent6>
              <a:hlink><a:srgbClr val="0000FF"/></a:hlink><a:folHlink><a:srgbClr val="800080"/></a:folHlink>
            </a:clrScheme>
            <a:fontScheme name="Office"><a:majorFont><a:latin typeface="Helvetica"/></a:majorFont><a:minorFont><a:latin typeface="Helvetica"/></a:minorFont></a:fontScheme>
            <a:fmtScheme name="Office"><a:fillStyleLst><a:solidFill><a:schemeClr val="phClr"/></a:solidFill></a:fillStyleLst><a:lnStyleLst><a:ln w="9525"><a:solidFill><a:schemeClr val="phClr"/></a:solidFill></a:ln></a:lnStyleLst><a:effectStyleLst><a:effectStyle><a:effectLst/></a:effectStyle></a:effectStyleLst><a:bgFillStyleLst><a:solidFill><a:schemeClr val="phClr"/></a:solidFill></a:bgFillStyleLst></a:fmtScheme>
          </a:themeElements>
        </a:theme>
        """.utf8)))

        try writeStoredZip(entries: entries, to: url)
    }

    static func writeMinimalFloatingDOCX(to url: URL) throws {
        let entries: [(String, Data)] = [
            ("[Content_Types].xml", Data("""
            <?xml version="1.0" encoding="UTF-8"?>
            <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
              <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
              <Default Extension="xml" ContentType="application/xml"/>
              <Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
            </Types>
            """.utf8)),
            ("_rels/.rels", Data("""
            <?xml version="1.0" encoding="UTF-8"?>
            <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
              <Relationship Id="rOffice" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>
            </Relationships>
            """.utf8)),
            ("word/document.xml", Data("""
            <?xml version="1.0" encoding="UTF-8"?>
            <w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"
                        xmlns:wp="http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing"
                        xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main"
                        xmlns:wps="http://schemas.microsoft.com/office/word/2010/wordprocessingShape">
              <w:body>
                <w:p>
                  <w:r>
                    <w:drawing>
                      <wp:anchor behindDoc="0" distT="0" distB="0" distL="114300" distR="114300">
                        <wp:positionH relativeFrom="margin"><wp:align>left</wp:align></wp:positionH>
                        <wp:positionV relativeFrom="paragraph"><wp:posOffset>0</wp:posOffset></wp:positionV>
                        <wp:extent cx="1828800" cy="914400"/>
                        <wp:wrapSquare wrapText="bothSides"/>
                        <wp:docPr id="1" name="FloatingBox"/>
                        <a:graphic>
                          <a:graphicData uri="http://schemas.microsoft.com/office/word/2010/wordprocessingShape">
                            <wps:wsp>
                              <wps:spPr>
                                <a:xfrm><a:off x="0" y="0"/><a:ext cx="1828800" cy="914400"/></a:xfrm>
                                <a:prstGeom prst="rect"><a:avLst/></a:prstGeom>
                                <a:solidFill><a:srgbClr val="DCE8FF"/></a:solidFill>
                              </wps:spPr>
                              <wps:txbx>
                                <w:txbxContent>
                                  <w:p><w:r><w:t>FloatingShapeKeyword</w:t></w:r></w:p>
                                </w:txbxContent>
                              </wps:txbx>
                            </wps:wsp>
                          </a:graphicData>
                        </a:graphic>
                      </wp:anchor>
                    </w:drawing>
                  </w:r>
                  <w:r><w:t>BodyParagraphKeyword wrapped beside floating shape.</w:t></w:r>
                </w:p>
                <w:sectPr><w:pgSz w="11906" h="16838"/></w:sectPr>
              </w:body>
            </w:document>
            """.utf8)),
            ("word/_rels/document.xml.rels", Data("""
            <?xml version="1.0" encoding="UTF-8"?>
            <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"/>
            """.utf8))
        ]
        try writeStoredZip(entries: entries, to: url)
    }

    static func writeMinimalXLSX(to url: URL, sheets: [(name: String, headerText: String)]) throws {
        var sheetNodes = ""
        var workbookRels = """
        <?xml version="1.0" encoding="UTF-8"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
        """
        var overrides = """
        <Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>
        """
        var entries: [(String, Data)] = [
            ("_rels/.rels", Data("""
            <?xml version="1.0" encoding="UTF-8"?>
            <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
              <Relationship Id="rOffice" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>
            </Relationships>
            """.utf8))
        ]

        for (idx, sheet) in sheets.enumerated() {
            let num = idx + 1
            let rId = "rSheet\(num)"
            sheetNodes += "<sheet name=\"\(sheet.name)\" sheetId=\"\(num)\" r:id=\"\(rId)\"/>"
            workbookRels += "<Relationship Id=\"\(rId)\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet\" Target=\"worksheets/sheet\(num).xml\"/>"
            overrides += "<Override PartName=\"/xl/worksheets/sheet\(num).xml\" ContentType=\"application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml\"/>"
            let xml = """
            <?xml version="1.0" encoding="UTF-8"?>
            <worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
              <sheetData>
                <row r="1"><c r="A1" t="inlineStr"><is><t>\(sheet.headerText)</t></is></c></row>
              </sheetData>
            </worksheet>
            """
            entries.append(("xl/worksheets/sheet\(num).xml", Data(xml.utf8)))
        }
        workbookRels += "</Relationships>"

        entries.append(("[Content_Types].xml", Data("""
        <?xml version="1.0" encoding="UTF-8"?>
        <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
          <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
          <Default Extension="xml" ContentType="application/xml"/>
          \(overrides)
        </Types>
        """.utf8)))
        entries.append(("xl/workbook.xml", Data("""
        <?xml version="1.0" encoding="UTF-8"?>
        <workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"
                  xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
          <sheets>\(sheetNodes)</sheets>
        </workbook>
        """.utf8)))
        entries.append(("xl/_rels/workbook.xml.rels", Data(workbookRels.utf8)))
        try writeStoredZip(entries: entries, to: url)
    }

    private static func writeStoredZip(entries: [(String, Data)], to url: URL) throws {
        var body = Data()
        var centralDirectory = Data()

        for (name, content) in entries {
            let nameData = Data(name.utf8)
            let checksum = crc32(content)
            let localOffset = UInt32(body.count)

            body.appendLE(UInt32(0x04034b50))
            body.appendLE(UInt16(20))
            body.appendLE(UInt16(0x0800))
            body.appendLE(UInt16(0))
            body.appendLE(UInt16(0))
            body.appendLE(UInt16(0))
            body.appendLE(checksum)
            body.appendLE(UInt32(content.count))
            body.appendLE(UInt32(content.count))
            body.appendLE(UInt16(nameData.count))
            body.appendLE(UInt16(0))
            body.append(nameData)
            body.append(content)

            centralDirectory.appendLE(UInt32(0x02014b50))
            centralDirectory.appendLE(UInt16(20))
            centralDirectory.appendLE(UInt16(20))
            centralDirectory.appendLE(UInt16(0x0800))
            centralDirectory.appendLE(UInt16(0))
            centralDirectory.appendLE(UInt16(0))
            centralDirectory.appendLE(UInt16(0))
            centralDirectory.appendLE(checksum)
            centralDirectory.appendLE(UInt32(content.count))
            centralDirectory.appendLE(UInt32(content.count))
            centralDirectory.appendLE(UInt16(nameData.count))
            centralDirectory.appendLE(UInt16(0))
            centralDirectory.appendLE(UInt16(0))
            centralDirectory.appendLE(UInt16(0))
            centralDirectory.appendLE(UInt16(0))
            centralDirectory.appendLE(UInt32(0))
            centralDirectory.appendLE(localOffset)
            centralDirectory.append(nameData)
        }

        let cdOffset = UInt32(body.count)
        let cdSize = UInt32(centralDirectory.count)
        body.append(centralDirectory)

        body.appendLE(UInt32(0x06054b50))
        body.appendLE(UInt16(0))
        body.appendLE(UInt16(0))
        body.appendLE(UInt16(entries.count))
        body.appendLE(UInt16(entries.count))
        body.appendLE(cdSize)
        body.appendLE(cdOffset)
        body.appendLE(UInt16(0))

        try body.write(to: url, options: .atomic)
    }

    private static let crcTable: [UInt32] = (0..<256).map { i in
        var c = UInt32(i)
        for _ in 0..<8 {
            c = (c & 1) != 0 ? (0xEDB88320 ^ (c >> 1)) : (c >> 1)
        }
        return c
    }

    private static func crc32(_ data: Data) -> UInt32 {
        var crc: UInt32 = 0xFFFF_FFFF
        for byte in data {
            let idx = Int((crc ^ UInt32(byte)) & 0xFF)
            crc = crcTable[idx] ^ (crc >> 8)
        }
        return crc ^ 0xFFFF_FFFF
    }
}

private extension Data {
    mutating func appendLE(_ value: UInt16) {
        var v = value.littleEndian
        Swift.withUnsafeBytes(of: &v) { append(contentsOf: $0) }
    }

    mutating func appendLE(_ value: UInt32) {
        var v = value.littleEndian
        Swift.withUnsafeBytes(of: &v) { append(contentsOf: $0) }
    }
}
