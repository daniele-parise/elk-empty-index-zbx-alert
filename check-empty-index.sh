#!/bin/bash



if [ $# -ne 4 ]
  then
    echo "USAGE: <index name> <hours ago from which start the query (integer)> <zabbix-host> <zabbix-item-key>"
    echo "\n"
    echo "EXAMPLE: ./script 'index-name*' 3 'zbx elastic host' 'zbx trapper item key'"
    exit
fi


re='^[0-9]+$'

data="$2 hours ago"

from=$(date -d "$(date --date="$data" '+20%y-%m-%d %H:%M')" +'%s%3N')
 
now=$(date -d "$(date '+20%y-%m-%d %H:%M:%S')" +'%s%3N')

index=$1




function get-index-hit {



	curl -s -XGET "http://elastic-host:9200/$index/_search" -H 'Content-Type: application/json' -d'
	{
	  "version": true,
	  "size": 500,
	  "sort": [
	    {
	      "timestamp": {
		"order": "desc",
		"unmapped_type": "boolean"
	      }
	    }
	  ],
	  "query": {
	    "bool": {
	      "must": [
		{
		  "match_all": {}
		},
		{
		  "range": {
		    "@timestamp": {
		      "gte": '$from',
		      "lte": '$now',
		      "format": "epoch_millis"
		    }
		  }
		}
	      ],
	      "must_not": []
	    }
	  },
	  "_source": {
	    "excludes": []
	  },
	  "aggs": {
	    "2": {
	      "date_histogram": {
		"field": "@timestamp",
		"interval": "5m",
		"time_zone": "Europe/Berlin",
		"min_doc_count": 1
	      }
	    }
	  },
	  "stored_fields": [
	    "*"
	  ],
	  "script_fields": {},
	  "docvalue_fields": [
	    "@timestamp"
	  ],
	  "highlight": {
	    "pre_tags": [
	      "@kibana-highlighted-field@"
	    ],
	    "post_tags": [
	      "@/kibana-highlighted-field@"
	    ],
	    "fields": {
	      "*": {
		"highlight_query": {
		  "bool": {
		    "must": [
		      {
			"match_all": {}
		      },
		      {
			"range": {
			  "@timestamp": {
			    "gte": '$from',
			    "lte": '$now',
			    "format": "epoch_millis"
			  }
			}
		      }
		    ],
		    "must_not": []
		  }
		}
	      }
	    },
	    "fragment_size": 2147483647
	  }

	}' | jq '.["hits"]["total"]'

}




if [ $(get-index-hit) -eq 0 ];
then
	echo "non ci sono hit nelle ultime tre ore"
	zabbix_sender -z "zabbix-server" -s "$3" -k "$4" -o 1
else
	if ! [[ $(get-index-hit) =~ $re ]] ; then
   		echo "error occurred executing the query"; exit 1
	fi 
	echo "ci sono $(get-index-hit) hit nelle ultime $2 ore" 
	zabbix_sender -z "zabbix-server" -s "$3" -k "$4" -o 0
fi
	



 



