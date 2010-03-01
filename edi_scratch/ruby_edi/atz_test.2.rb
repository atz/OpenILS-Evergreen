#!/usr/bin/env ruby

require 'rubygems'
require 'openils/mapper'
require 'edi/edi2json'

json=''

DATA.each { |a_string|
  json = json + a_string
  puts a_string
}

@map = OpenILS::Mapper.from_json(json)
puts @map.finalize.to_s
__END__

{
 "msg_type": "ORDERS",
 "msg": ["order", {
    "po_number":6,
    "date":"20100301",
    "buyer":[
        {"id":"6666666",
         "reference":{"API":"6666666"}}
    ],
    "vendor":[         "0672891",
        {"id-qualifier":"91", "reference":{"IA":"1"}, "id":"0672891"}
    ],
    "currency":"USD",
    "items":[
        
        {
            "identifiers":[
                {"id-qualifier":"SA","id":"38"},
                {"id-qualifier":"IB","id":""}
            ],
            "price":9.99,
            "desc":[
                {"BTI":"Twilight zone/twilight tone / arr. Paul Jennings"}, 
                {"BPU":"Jenson Publications,"},
                {"BPD":"1982, c1979"},
                {"BPH":"1 score + parts"}
            ],
            "quantity":4        },
        
        {
            "identifiers":[
                {"id-qualifier":"SA","id":"40"},
                {"id-qualifier":"IB","id":"0393048799"}
            ],
            "price":16.44,
            "desc":[
                {"BTI":"The twilight of American culture / Morris Berman."}, 
                {"BPU":"Norton,"},
                {"BPD":"c2000."},
                {"BPH":"xiv, 205 p. ;"}
            ],
            "quantity":3        },
        
        {
            "identifiers":[
                {"id-qualifier":"SA","id":"27"},
                {"id-qualifier":"IB","id":"0439139597"}
            ],
            "price":14.99,
            "desc":[
                {"BTI":"Harry Potter and the goblet of fire / by J.K. Rowling ; illustrations by Mary GrandPr\u00e9."}, 
                {"BPU":"Arthur A. Levine Books,"},
                {"BPD":"c2000."},
                {"BPH":"xi, 734 p. :"}
            ],
            "quantity":19        },
        
        {
            "identifiers":[
                {"id-qualifier":"SA","id":"30"},
                {"id-qualifier":"IB","id":"0786222735"}
            ],
            "price":15.99,
            "desc":[
                {"BTI":"Harry Potter and the Chamber of Secrets / J.K. Rowling ; illustrations by Mary GrandPr\u00e9."}, 
                {"BPU":"Thorndike Press,"},
                {"BPD":"1999."},
                {"BPH":"464 p. ; 22 cm."}
            ],
            "quantity":4        }
        
    ],
    "line_items":4
 }],
 "recipient":"0672891",
 "sender":"6666666"
}
