//
//  Util.swift
//  iOS Example
//
//  Created by liuguoqiang on 2024/1/10.
//  Copyright © 2024 Alamofire. All rights reserved.
//

import UIKit

extension UIColor {
    static var random: UIColor {
        let red = CGFloat.random(in: 0...1)
        let green = CGFloat.random(in: 0...1)
        let blue = CGFloat.random(in: 0...1)
        let alpha = CGFloat.random(in: 0.5...1) // 可以选择透明度范围
        return UIColor(red: red, green: green, blue: blue, alpha: alpha)
    }
}

import Foundation

class DataFetcher {

    func fetchData() {
        guard let fileURL = Bundle.main.url(forResource: "JSONExample", withExtension: "txt"),
              let fileContents = try? String(contentsOf: fileURL) else {
            print("File not found or cannot be read")
            return
        }

        guard let dataURL = URL(string: "data:application/json;base64,\(fileContents)") else {
            print("Invalid data URL")
            return
        }

        let task = URLSession.shared.dataTask(with: dataURL) { data, response, error in
            if let error = error {
                print("Error fetching data: \(error)")
                return
            }

            if let data = data {
                // 处理数据，例如解析 JSON
                print("Data fetched: \(data)")
            }
        }
        task.resume()
    }
}

import Foundation

extension String {
    func writeTo(url: URL) -> Bool {
        do {
            try self.write(to: url, atomically: true, encoding: .utf8)
            return true
        } catch {
            print("Failed to write to URL: \(error)")
            return false
        }
    }
}


let kArticle =
"""
先帝创业未半而中道崩殂，今天下三分，益州疲弊，此诚危急存亡之秋也。然侍卫之臣不懈于内，忠志之士忘身于外者，盖追先帝之殊遇，欲报之于陛下也。诚宜开张圣听，以光先帝遗德，恢弘志士之气，不宜妄自菲薄，引喻失义，以塞忠谏之路也。

宫中府中，俱为一体，陟罚臧否，不宜异同。若有作奸犯科及为忠善者，宜付有司论其刑赏，以昭陛下平明之理，不宜偏私，使内外异法也。

侍中、侍郎郭攸之、费祎、董允等，此皆良实，志虑忠纯，是以先帝简拔以遗陛下。愚以为宫中之事，事无大小，悉以咨之，然后施行，必能裨补阙漏，有所广益。

将军向宠，性行淑均，晓畅军事，试用于昔日，先帝称之曰能，是以众议举宠为督。愚以为营中之事，悉以咨之，必能使行阵和睦，优劣得所。

亲贤臣，远小人，此先汉所以兴隆也；亲小人，远贤臣，此后汉所以倾颓也。先帝在时，每与臣论此事，未尝不叹息痛恨于桓、灵也。侍中、尚书、长史、参军，此悉贞良死节之臣，愿陛下亲之信之，则汉室之隆，可计日而待也。

臣本布衣，躬耕于南阳，苟全性命于乱世，不求闻达于诸侯。先帝不以臣卑鄙，猥自枉屈，三顾臣于草庐之中，咨臣以当世之事，由是感激，遂许先帝以驱驰。后值倾覆，受任于败军之际，奉命于危难之间，尔来二十有一年矣。

先帝知臣谨慎，故临崩寄臣以大事也。受命以来，夙夜忧叹，恐托付不效，以伤先帝之明，故五月渡泸，深入不毛。今南方已定，兵甲已足，当奖率三军，北定中原，庶竭驽钝，攘除奸凶，兴复汉室，还于旧都。此臣所以报先帝而忠陛下之职分也。至于斟酌损益，进尽忠言，则攸之、祎、允之任也。

愿陛下托臣以讨贼兴复之效，不效，则治臣之罪，以告先帝之灵。若无兴德之言，则责攸之、祎、允等之慢，以彰其咎；陛下亦宜自谋，以咨诹善道，察纳雅言，深追先帝遗诏，臣不胜受恩感激。

今当远离，临表涕零，不知所言。
"""
