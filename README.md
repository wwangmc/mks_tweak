
{
	"taskType": "input",
	"content": "xxx"
}


{
	"taskType": "getClip",
	"content": ""
}

{
    "taskType": "toast",
    "content": {
        "type": "success",
        "content": "牢底还得练",
        "duration": 2.5,
        "position": "top",  
        "fontSize": 16                 
    }
}

{
	"taskType": "deviceInfo",
	"content": ""
}

{
	"taskType":"runShell",
	"content": "ls /var/root"
}

{
	"taskType":"sandboxPath",
	"content": "com.liguangming.Shadowrocket"
}

{
	"taskType":"touch",
	"content": {
		  "x": 119,
		  "y": 871,
		  "index": 1,
		  "type": "down"
	}

}

查ip
{
	"taskType":"runShell",
	"content": "curl -s http://ip-api.com/json"
}
