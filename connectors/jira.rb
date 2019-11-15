require 'net/http'
require 'uri'
require 'json'
require 'date'

module Connectors
  class Jira

    ROUTES = {
      boards: '/rest/agile/1.0/board',
      sprints_for_board: '/rest/agile/1.0/board/%{board_id}/sprint',
      issues_for_board: '/rest/agile/1.0/board/%{board_id}/issue',
      issues_for_sprint: '/rest/agile/1.0/board/%{board_id}/sprint/%{sprint_id}/issue',
      velocities_for_board: '/rest/greenhopper/1.0/rapid/charts/velocity?rapidViewId=%{board_id}'
    }

    def initialize
      @domain = ENV.fetch('DOMAIN')
      @api_key = ENV.fetch('API_KEY')
      @username = ENV.fetch('USERNAME')

      raise "Incomplete configuration. Ensure all envars are set: [DOMAIN, API_KEY, USERNAME]." unless @domain && @api_key && @username

      @host = "https://#{@domain}.atlassian.net"
    end

    def list_boards
      process_paginated(:boards)
    end

    def list_sprints(board_id)
      # Sample response:
      # [
      #   {
      #     "id": 63,
      #     "self": "https://scalefactor.atlassian.net/rest/agile/1.0/sprint/63",
      #     "state": "closed",
      #     "name": "Q1 Sprint 5 2019/03/05-2019/03/16",
      #     "startDate": "2019-03-05T14:50:05.904Z",
      #     "endDate": "2019-03-16T14:50:00.000Z",
      #     "completeDate": "2019-04-04T15:56:36.824Z",
      #     "originBoardId": 38,
      #     "goal": ""
      #   }, {
      #     "id": 180,
      #     "self": "https://scalefactor.atlassian.net/rest/agile/1.0/sprint/180",
      #     "state": "active",
      #     "name": "PE Q2 Sprint 9 2019",
      #     "startDate": "2019-06-10T20:48:13.224Z",
      #     "endDate": "2019-06-15T06:48:00.000Z",
      #     "originBoardId": 42,
      #     "goal": ""
      #   },
      #   ...
      # ]
      response = process_paginated(:sprints_for_board, { board_id: board_id })
      response.select! { |sh| sh["name"] && sh["startDate"] && sh["endDate"] }
      response
    end

    def list_issues(board_id, sprint_id=nil)
      # Sample response:
      # [{
      #   "expand": "operations,versionedRepresentations,editmeta,changelog,renderedFields",
      #   "id": "21317",
      #   "self": "https://scalefactor.atlassian.net/rest/agile/1.0/issue/21317",
      #   "key": "AC-290",
      #   "fields": {
      #     "statuscategorychangedate": "2019-06-19T09:42:50.204-0500",
      #     "issuetype": {
      #       "self": "https://scalefactor.atlassian.net/rest/api/2/issuetype/10001",
      #       "id": "10001",
      #       "description": "Stories track functionality or features expressed as user goals.",
      #       "iconUrl": "https://scalefactor.atlassian.net/images/icons/issuetypes/story.svg",
      #       "name": "Story",
      #       "subtask": false
      #     },
      #     "timespent": null,
      #     "sprint": {
      #       "id": 200,
      #       "self": "https://scalefactor.atlassian.net/rest/agile/1.0/sprint/200",
      #       "state": "active",
      #       "name": "AC Q2 Sprint 10 2019",
      #       "startDate": "2019-06-17T14:05:29.755Z",
      #       "endDate": "2019-06-24T14:05:00.000Z",
      #       "originBoardId": 67,
      #       "goal": ""
      #     },
      #     "customfield_10030": null,
      #     "customfield_10031": [],
      #     "project": {
      #       "self": "https://scalefactor.atlassian.net/rest/api/2/project/10046",
      #       "id": "10046",
      #       "key": "AC",
      #       "name": "Home",
      #       "projectTypeKey": "software",
      #       "simplified": false,
      #       "avatarUrls": {
      #         "48x48": "https://scalefactor.atlassian.net/secure/projectavatar?pid=10046&avatarId=10560",
      #         "24x24": "https://scalefactor.atlassian.net/secure/projectavatar?size=small&s=small&pid=10046&avatarId=10560",
      #         "16x16": "https://scalefactor.atlassian.net/secure/projectavatar?size=xsmall&s=xsmall&pid=10046&avatarId=10560",
      #         "32x32": "https://scalefactor.atlassian.net/secure/projectavatar?size=medium&s=medium&pid=10046&avatarId=10560"
      #       }
      #     },
      #     "customfield_10032": null,
      #     "customfield_10033": null,
      #     "fixVersions": [],
      #     "aggregatetimespent": null,
      #     "resolution": null,
      #     "customfield_10027": null,
      #     "customfield_10028": null,
      #     "customfield_10029": null,
      #     "resolutiondate": null,
      #     "workratio": -1,
      #     "watches": {
      #       "self": "https://scalefactor.atlassian.net/rest/api/2/issue/AC-290/watchers",
      #       "watchCount": 2,
      #       "isWatching": false
      #     },
      #     "lastViewed": "2019-06-05T17:31:50.646-0500",
      #     "customfield_10060": null,
      #     "created": "2019-05-24T17:20:22.334-0500",
      #     "epic": {
      #       "id": 21315,
      #       "key": "AC-288",
      #       "self": "https://scalefactor.atlassian.net/rest/agile/1.0/epic/21315",
      #       "name": "Plaid Asset Report Improvements",
      #       "summary": "Improve Plaid Asset Report usability",
      #       "color": {
      #         "key": "color_6"
      #       },
      #       "done": false
      #     },
      #     "priority": {
      #       "self": "https://scalefactor.atlassian.net/rest/api/2/priority/3",
      #       "iconUrl": "https://scalefactor.atlassian.net/images/icons/priorities/medium.svg",
      #       "name": "Medium",
      #       "id": "3"
      #     },
      #     "customfield_10025": null,
      #     "customfield_10026": null,
      #     "labels": [],
      #     "customfield_10017": null,
      #     "aggregatetimeoriginalestimate": null,
      #     "timeestimate": null,
      #     "versions": [],
      #     "issuelinks": [],
      #     "assignee": {
      #       "self": "https://scalefactor.atlassian.net/rest/api/2/user?accountId=5bb53900210f980c53dcbb0f",
      #       "name": "alexkovtunov",
      #       "key": "alexkovtunov",
      #       "accountId": "5bb53900210f980c53dcbb0f",
      #       "emailAddress": "alexkovtunov@scalefactor.com",
      #       "avatarUrls": {
      #         "48x48": "https://avatar-cdn.atlassian.com/8fa90a0c6355a343b61ccb0f3426e43a?s=48&d=https%3A%2F%2Fsecure.gravatar.com%2Favatar%2F8fa90a0c6355a343b61ccb0f3426e43a%3Fd%3Dmm%26s%3D48%26noRedirect%3Dtrue",
      #         "24x24": "https://avatar-cdn.atlassian.com/8fa90a0c6355a343b61ccb0f3426e43a?s=24&d=https%3A%2F%2Fsecure.gravatar.com%2Favatar%2F8fa90a0c6355a343b61ccb0f3426e43a%3Fd%3Dmm%26s%3D24%26noRedirect%3Dtrue",
      #         "16x16": "https://avatar-cdn.atlassian.com/8fa90a0c6355a343b61ccb0f3426e43a?s=16&d=https%3A%2F%2Fsecure.gravatar.com%2Favatar%2F8fa90a0c6355a343b61ccb0f3426e43a%3Fd%3Dmm%26s%3D16%26noRedirect%3Dtrue",
      #         "32x32": "https://avatar-cdn.atlassian.com/8fa90a0c6355a343b61ccb0f3426e43a?s=32&d=https%3A%2F%2Fsecure.gravatar.com%2Favatar%2F8fa90a0c6355a343b61ccb0f3426e43a%3Fd%3Dmm%26s%3D32%26noRedirect%3Dtrue"
      #       },
      #       "displayName": "Alex Kovtunov",
      #       "active": true,
      #       "timeZone": "Africa/Ceuta",
      #       "accountType": "atlassian"
      #     },
      #     "updated": "2019-06-19T09:42:50.204-0500",
      #     "status": {
      #       "self": "https://scalefactor.atlassian.net/rest/api/2/status/1",
      #       "description": "The issue is open and ready for the assignee to start work on it.",
      #       "iconUrl": "https://scalefactor.atlassian.net/images/icons/statuses/open.png",
      #       "name": "ToDo",
      #       "id": "1",
      #       "statusCategory": {
      #         "self": "https://scalefactor.atlassian.net/rest/api/2/statuscategory/2",
      #         "id": 2,
      #         "key": "new",
      #         "colorName": "blue-gray",
      #         "name": "To Do"
      #       }
      #     },
      #     "components": [],
      #     "timeoriginalestimate": null,
      #     "description": "I want to select and deselect the asset reports to download\r\n\r\n\r\n\r\n\r\nOld: \r\nACriteria:\r\n1. I want to select and deselect the asset reports to sync\r\n2. I want to view the sync status of an asset report\r\n3. I want to download an asset report from .csv\r\n4. I should see the last successful sync date for each account\r\n5. I should see last sync attempted date",
      #     "customfield_10010": ["com.atlassian.greenhopper.service.sprint.Sprint@11612143[id=200,rapidViewId=67,state=ACTIVE,name=AC Q2 Sprint 10 2019,goal=,startDate=2019-06-17T14:05:29.755Z,endDate=2019-06-24T14:05:00.000Z,completeDate=<null>,sequence=200]"],
      #     "customfield_10011": "1|hzzzkz:06h0000000t100v",
      #     "customfield_10012": "2019-05-30T17:21:09.683-0500",
      #     "customfield_10013": null,
      #     "customfield_10057": null,
      #     "customfield_10014": 5.0,
      #     "timetracking": {},
      #     "customfield_10049": null,
      #     "security": null,
      #     "customfield_10008": "AC-288",
      #     "customfield_10009": {
      #       "hasEpicLinkFieldDependency": false,
      #       "showField": false,
      #       "nonEditableReason": {
      #         "reason": "PLUGIN_LICENSE_ERROR",
      #         "message": "Portfolio for Jira must be licensed for the Parent Link to be available."
      #       }
      #     },
      #     "aggregatetimeestimate": null,
      #     "attachment": [{
      #       "self": "https://scalefactor.atlassian.net/rest/api/2/attachment/13724",
      #       "id": "13724",
      #       "filename": "screenshot-1.png",
      #       "author": {
      #         "self": "https://scalefactor.atlassian.net/rest/api/2/user?accountId=5bb53900210f980c53dcbb0f",
      #         "name": "alexkovtunov",
      #         "key": "alexkovtunov",
      #         "accountId": "5bb53900210f980c53dcbb0f",
      #         "emailAddress": "alexkovtunov@scalefactor.com",
      #         "avatarUrls": {
      #           "48x48": "https://avatar-cdn.atlassian.com/8fa90a0c6355a343b61ccb0f3426e43a?s=48&d=https%3A%2F%2Fsecure.gravatar.com%2Favatar%2F8fa90a0c6355a343b61ccb0f3426e43a%3Fd%3Dmm%26s%3D48%26noRedirect%3Dtrue",
      #           "24x24": "https://avatar-cdn.atlassian.com/8fa90a0c6355a343b61ccb0f3426e43a?s=24&d=https%3A%2F%2Fsecure.gravatar.com%2Favatar%2F8fa90a0c6355a343b61ccb0f3426e43a%3Fd%3Dmm%26s%3D24%26noRedirect%3Dtrue",
      #           "16x16": "https://avatar-cdn.atlassian.com/8fa90a0c6355a343b61ccb0f3426e43a?s=16&d=https%3A%2F%2Fsecure.gravatar.com%2Favatar%2F8fa90a0c6355a343b61ccb0f3426e43a%3Fd%3Dmm%26s%3D16%26noRedirect%3Dtrue",
      #           "32x32": "https://avatar-cdn.atlassian.com/8fa90a0c6355a343b61ccb0f3426e43a?s=32&d=https%3A%2F%2Fsecure.gravatar.com%2Favatar%2F8fa90a0c6355a343b61ccb0f3426e43a%3Fd%3Dmm%26s%3D32%26noRedirect%3Dtrue"
      #         },
      #         "displayName": "Alex Kovtunov",
      #         "active": true,
      #         "timeZone": "Africa/Ceuta",
      #         "accountType": "atlassian"
      #       },
      #       "created": "2019-06-04T08:02:01.494-0500",
      #       "size": 33852,
      #       "mimeType": "image/png",
      #       "content": "https://scalefactor.atlassian.net/secure/attachment/13724/screenshot-1.png",
      #       "thumbnail": "https://scalefactor.atlassian.net/secure/thumbnail/13724/screenshot-1.png"
      #     }, {
      #       "self": "https://scalefactor.atlassian.net/rest/api/2/attachment/13725",
      #       "id": "13725",
      #       "filename": "screenshot-2.png",
      #       "author": {
      #         "self": "https://scalefactor.atlassian.net/rest/api/2/user?accountId=5bb53900210f980c53dcbb0f",
      #         "name": "alexkovtunov",
      #         "key": "alexkovtunov",
      #         "accountId": "5bb53900210f980c53dcbb0f",
      #         "emailAddress": "alexkovtunov@scalefactor.com",
      #         "avatarUrls": {
      #           "48x48": "https://avatar-cdn.atlassian.com/8fa90a0c6355a343b61ccb0f3426e43a?s=48&d=https%3A%2F%2Fsecure.gravatar.com%2Favatar%2F8fa90a0c6355a343b61ccb0f3426e43a%3Fd%3Dmm%26s%3D48%26noRedirect%3Dtrue",
      #           "24x24": "https://avatar-cdn.atlassian.com/8fa90a0c6355a343b61ccb0f3426e43a?s=24&d=https%3A%2F%2Fsecure.gravatar.com%2Favatar%2F8fa90a0c6355a343b61ccb0f3426e43a%3Fd%3Dmm%26s%3D24%26noRedirect%3Dtrue",
      #           "16x16": "https://avatar-cdn.atlassian.com/8fa90a0c6355a343b61ccb0f3426e43a?s=16&d=https%3A%2F%2Fsecure.gravatar.com%2Favatar%2F8fa90a0c6355a343b61ccb0f3426e43a%3Fd%3Dmm%26s%3D16%26noRedirect%3Dtrue",
      #           "32x32": "https://avatar-cdn.atlassian.com/8fa90a0c6355a343b61ccb0f3426e43a?s=32&d=https%3A%2F%2Fsecure.gravatar.com%2Favatar%2F8fa90a0c6355a343b61ccb0f3426e43a%3Fd%3Dmm%26s%3D32%26noRedirect%3Dtrue"
      #         },
      #         "displayName": "Alex Kovtunov",
      #         "active": true,
      #         "timeZone": "Africa/Ceuta",
      #         "accountType": "atlassian"
      #       },
      #       "created": "2019-06-04T08:03:10.931-0500",
      #       "size": 85372,
      #       "mimeType": "image/png",
      #       "content": "https://scalefactor.atlassian.net/secure/attachment/13725/screenshot-2.png",
      #       "thumbnail": "https://scalefactor.atlassian.net/secure/thumbnail/13725/screenshot-2.png"
      #     }],
      #     "flagged": false,
      #     "summary": "I want to request multiple asset reports at once and see their sync status in the back office portal",
      #     "creator": {
      #       "self": "https://scalefactor.atlassian.net/rest/api/2/user?accountId=5c3a1dd00ecffa5e96d9340a",
      #       "name": "kennyjohnson",
      #       "key": "kennyjohnson",
      #       "accountId": "5c3a1dd00ecffa5e96d9340a",
      #       "emailAddress": "kennyjohnson@scalefactor.com",
      #       "avatarUrls": {
      #         "48x48": "https://avatar-cdn.atlassian.com/5a4d1efd76bedf80c8d004917b3881ba?s=48&d=https%3A%2F%2Fsecure.gravatar.com%2Favatar%2F5a4d1efd76bedf80c8d004917b3881ba%3Fd%3Dmm%26s%3D48%26noRedirect%3Dtrue",
      #         "24x24": "https://avatar-cdn.atlassian.com/5a4d1efd76bedf80c8d004917b3881ba?s=24&d=https%3A%2F%2Fsecure.gravatar.com%2Favatar%2F5a4d1efd76bedf80c8d004917b3881ba%3Fd%3Dmm%26s%3D24%26noRedirect%3Dtrue",
      #         "16x16": "https://avatar-cdn.atlassian.com/5a4d1efd76bedf80c8d004917b3881ba?s=16&d=https%3A%2F%2Fsecure.gravatar.com%2Favatar%2F5a4d1efd76bedf80c8d004917b3881ba%3Fd%3Dmm%26s%3D16%26noRedirect%3Dtrue",
      #         "32x32": "https://avatar-cdn.atlassian.com/5a4d1efd76bedf80c8d004917b3881ba?s=32&d=https%3A%2F%2Fsecure.gravatar.com%2Favatar%2F5a4d1efd76bedf80c8d004917b3881ba%3Fd%3Dmm%26s%3D32%26noRedirect%3Dtrue"
      #       },
      #       "displayName": "Kenny Johnson",
      #       "active": true,
      #       "timeZone": "America/Chicago",
      #       "accountType": "atlassian"
      #     },
      #     "subtasks": [],
      #     "reporter": {
      #       "self": "https://scalefactor.atlassian.net/rest/api/2/user?accountId=5c3a1dd00ecffa5e96d9340a",
      #       "name": "kennyjohnson",
      #       "key": "kennyjohnson",
      #       "accountId": "5c3a1dd00ecffa5e96d9340a",
      #       "emailAddress": "kennyjohnson@scalefactor.com",
      #       "avatarUrls": {
      #         "48x48": "https://avatar-cdn.atlassian.com/5a4d1efd76bedf80c8d004917b3881ba?s=48&d=https%3A%2F%2Fsecure.gravatar.com%2Favatar%2F5a4d1efd76bedf80c8d004917b3881ba%3Fd%3Dmm%26s%3D48%26noRedirect%3Dtrue",
      #         "24x24": "https://avatar-cdn.atlassian.com/5a4d1efd76bedf80c8d004917b3881ba?s=24&d=https%3A%2F%2Fsecure.gravatar.com%2Favatar%2F5a4d1efd76bedf80c8d004917b3881ba%3Fd%3Dmm%26s%3D24%26noRedirect%3Dtrue",
      #         "16x16": "https://avatar-cdn.atlassian.com/5a4d1efd76bedf80c8d004917b3881ba?s=16&d=https%3A%2F%2Fsecure.gravatar.com%2Favatar%2F5a4d1efd76bedf80c8d004917b3881ba%3Fd%3Dmm%26s%3D16%26noRedirect%3Dtrue",
      #         "32x32": "https://avatar-cdn.atlassian.com/5a4d1efd76bedf80c8d004917b3881ba?s=32&d=https%3A%2F%2Fsecure.gravatar.com%2Favatar%2F5a4d1efd76bedf80c8d004917b3881ba%3Fd%3Dmm%26s%3D32%26noRedirect%3Dtrue"
      #       },
      #       "displayName": "Kenny Johnson",
      #       "active": true,
      #       "timeZone": "America/Chicago",
      #       "accountType": "atlassian"
      #     },
      #     "customfield_10043": null,
      #     "aggregateprogress": {
      #       "progress": 0,
      #       "total": 0
      #     },
      #     "customfield_10000": "{pullrequest={dataType=pullrequest, state=DECLINED, stateCount=1}, json={\"cachedValue\":{\"errors\":[],\"summary\":{\"pullrequest\":{\"overall\":{\"count\":1,\"lastUpdated\":\"2019-06-04T17:53:31.000-0500\",\"stateCount\":1,\"state\":\"DECLINED\",\"dataType\":\"pullrequest\",\"open\":false},\"byInstanceType\":{\"github\":{\"count\":1,\"name\":\"GitHub\"}}}}},\"isStale\":true}}",
      #     "customfield_10001": null,
      #     "customfield_10004": null,
      #     "environment": null,
      #     "duedate": null,
      #     "progress": {
      #       "progress": 0,
      #       "total": 0
      #     },
      #     "votes": {
      #       "self": "https://scalefactor.atlassian.net/rest/api/2/issue/AC-290/votes",
      #       "votes": 0,
      #       "hasVoted": false
      #     },
      #     "comment": {
      #       "comments": [{
      #         "self": "https://scalefactor.atlassian.net/rest/api/2/issue/21317/comment/20701",
      #         "id": "20701",
      #         "author": {
      #           "self": "https://scalefactor.atlassian.net/rest/api/2/user?accountId=5c3a1dd00ecffa5e96d9340a",
      #           "name": "kennyjohnson",
      #           "key": "kennyjohnson",
      #           "accountId": "5c3a1dd00ecffa5e96d9340a",
      #           "emailAddress": "kennyjohnson@scalefactor.com",
      #           "avatarUrls": {
      #             "48x48": "https://avatar-cdn.atlassian.com/5a4d1efd76bedf80c8d004917b3881ba?s=48&d=https%3A%2F%2Fsecure.gravatar.com%2Favatar%2F5a4d1efd76bedf80c8d004917b3881ba%3Fd%3Dmm%26s%3D48%26noRedirect%3Dtrue",
      #             "24x24": "https://avatar-cdn.atlassian.com/5a4d1efd76bedf80c8d004917b3881ba?s=24&d=https%3A%2F%2Fsecure.gravatar.com%2Favatar%2F5a4d1efd76bedf80c8d004917b3881ba%3Fd%3Dmm%26s%3D24%26noRedirect%3Dtrue",
      #             "16x16": "https://avatar-cdn.atlassian.com/5a4d1efd76bedf80c8d004917b3881ba?s=16&d=https%3A%2F%2Fsecure.gravatar.com%2Favatar%2F5a4d1efd76bedf80c8d004917b3881ba%3Fd%3Dmm%26s%3D16%26noRedirect%3Dtrue",
      #             "32x32": "https://avatar-cdn.atlassian.com/5a4d1efd76bedf80c8d004917b3881ba?s=32&d=https%3A%2F%2Fsecure.gravatar.com%2Favatar%2F5a4d1efd76bedf80c8d004917b3881ba%3Fd%3Dmm%26s%3D32%26noRedirect%3Dtrue"
      #           },
      #           "displayName": "Kenny Johnson",
      #           "active": true,
      #           "timeZone": "America/Chicago",
      #           "accountType": "atlassian"
      #         },
      #         "body": "Alex immediately pickup AC‌-187 after completing this",
      #         "updateAuthor": {
      #           "self": "https://scalefactor.atlassian.net/rest/api/2/user?accountId=5c3a1dd00ecffa5e96d9340a",
      #           "name": "kennyjohnson",
      #           "key": "kennyjohnson",
      #           "accountId": "5c3a1dd00ecffa5e96d9340a",
      #           "emailAddress": "kennyjohnson@scalefactor.com",
      #           "avatarUrls": {
      #             "48x48": "https://avatar-cdn.atlassian.com/5a4d1efd76bedf80c8d004917b3881ba?s=48&d=https%3A%2F%2Fsecure.gravatar.com%2Favatar%2F5a4d1efd76bedf80c8d004917b3881ba%3Fd%3Dmm%26s%3D48%26noRedirect%3Dtrue",
      #             "24x24": "https://avatar-cdn.atlassian.com/5a4d1efd76bedf80c8d004917b3881ba?s=24&d=https%3A%2F%2Fsecure.gravatar.com%2Favatar%2F5a4d1efd76bedf80c8d004917b3881ba%3Fd%3Dmm%26s%3D24%26noRedirect%3Dtrue",
      #             "16x16": "https://avatar-cdn.atlassian.com/5a4d1efd76bedf80c8d004917b3881ba?s=16&d=https%3A%2F%2Fsecure.gravatar.com%2Favatar%2F5a4d1efd76bedf80c8d004917b3881ba%3Fd%3Dmm%26s%3D16%26noRedirect%3Dtrue",
      #             "32x32": "https://avatar-cdn.atlassian.com/5a4d1efd76bedf80c8d004917b3881ba?s=32&d=https%3A%2F%2Fsecure.gravatar.com%2Favatar%2F5a4d1efd76bedf80c8d004917b3881ba%3Fd%3Dmm%26s%3D32%26noRedirect%3Dtrue"
      #           },
      #           "displayName": "Kenny Johnson",
      #           "active": true,
      #           "timeZone": "America/Chicago",
      #           "accountType": "atlassian"
      #         },
      #         "created": "2019-05-30T17:01:02.775-0500",
      #         "updated": "2019-05-30T17:01:02.775-0500",
      #         "jsdPublic": true
      #       }, {
      #         "self": "https://scalefactor.atlassian.net/rest/api/2/issue/21317/comment/20705",
      #         "id": "20705",
      #         "author": {
      #           "self": "https://scalefactor.atlassian.net/rest/api/2/user?accountId=5bb53900210f980c53dcbb0f",
      #           "name": "alexkovtunov",
      #           "key": "alexkovtunov",
      #           "accountId": "5bb53900210f980c53dcbb0f",
      #           "emailAddress": "alexkovtunov@scalefactor.com",
      #           "avatarUrls": {
      #             "48x48": "https://avatar-cdn.atlassian.com/8fa90a0c6355a343b61ccb0f3426e43a?s=48&d=https%3A%2F%2Fsecure.gravatar.com%2Favatar%2F8fa90a0c6355a343b61ccb0f3426e43a%3Fd%3Dmm%26s%3D48%26noRedirect%3Dtrue",
      #             "24x24": "https://avatar-cdn.atlassian.com/8fa90a0c6355a343b61ccb0f3426e43a?s=24&d=https%3A%2F%2Fsecure.gravatar.com%2Favatar%2F8fa90a0c6355a343b61ccb0f3426e43a%3Fd%3Dmm%26s%3D24%26noRedirect%3Dtrue",
      #             "16x16": "https://avatar-cdn.atlassian.com/8fa90a0c6355a343b61ccb0f3426e43a?s=16&d=https%3A%2F%2Fsecure.gravatar.com%2Favatar%2F8fa90a0c6355a343b61ccb0f3426e43a%3Fd%3Dmm%26s%3D16%26noRedirect%3Dtrue",
      #             "32x32": "https://avatar-cdn.atlassian.com/8fa90a0c6355a343b61ccb0f3426e43a?s=32&d=https%3A%2F%2Fsecure.gravatar.com%2Favatar%2F8fa90a0c6355a343b61ccb0f3426e43a%3Fd%3Dmm%26s%3D32%26noRedirect%3Dtrue"
      #           },
      #           "displayName": "Alex Kovtunov",
      #           "active": true,
      #           "timeZone": "Africa/Ceuta",
      #           "accountType": "atlassian"
      #         },
      #         "body": "Can you explain me this one in more details? Maybe with some screenshots. \n\n\n>I want to select and deselect the asset reports to sync\n\n[~accountid:5c3a1dd00ecffa5e96d9340a] \n\nWhat is implemented right now and what reports can we select\\deselect?",
      #         "updateAuthor": {
      #           "self": "https://scalefactor.atlassian.net/rest/api/2/user?accountId=5bb53900210f980c53dcbb0f",
      #           "name": "alexkovtunov",
      #           "key": "alexkovtunov",
      #           "accountId": "5bb53900210f980c53dcbb0f",
      #           "emailAddress": "alexkovtunov@scalefactor.com",
      #           "avatarUrls": {
      #             "48x48": "https://avatar-cdn.atlassian.com/8fa90a0c6355a343b61ccb0f3426e43a?s=48&d=https%3A%2F%2Fsecure.gravatar.com%2Favatar%2F8fa90a0c6355a343b61ccb0f3426e43a%3Fd%3Dmm%26s%3D48%26noRedirect%3Dtrue",
      #             "24x24": "https://avatar-cdn.atlassian.com/8fa90a0c6355a343b61ccb0f3426e43a?s=24&d=https%3A%2F%2Fsecure.gravatar.com%2Favatar%2F8fa90a0c6355a343b61ccb0f3426e43a%3Fd%3Dmm%26s%3D24%26noRedirect%3Dtrue",
      #             "16x16": "https://avatar-cdn.atlassian.com/8fa90a0c6355a343b61ccb0f3426e43a?s=16&d=https%3A%2F%2Fsecure.gravatar.com%2Favatar%2F8fa90a0c6355a343b61ccb0f3426e43a%3Fd%3Dmm%26s%3D16%26noRedirect%3Dtrue",
      #             "32x32": "https://avatar-cdn.atlassian.com/8fa90a0c6355a343b61ccb0f3426e43a?s=32&d=https%3A%2F%2Fsecure.gravatar.com%2Favatar%2F8fa90a0c6355a343b61ccb0f3426e43a%3Fd%3Dmm%26s%3D32%26noRedirect%3Dtrue"
      #           },
      #           "displayName": "Alex Kovtunov",
      #           "active": true,
      #           "timeZone": "Africa/Ceuta",
      #           "accountType": "atlassian"
      #         },
      #         "created": "2019-05-30T17:21:09.683-0500",
      #         "updated": "2019-05-30T17:21:09.683-0500",
      #         "jsdPublic": true
      #       }, {
      #         "self": "https://scalefactor.atlassian.net/rest/api/2/issue/21317/comment/20855",
      #         "id": "20855",
      #         "author": {
      #           "self": "https://scalefactor.atlassian.net/rest/api/2/user?accountId=5bb53900210f980c53dcbb0f",
      #           "name": "alexkovtunov",
      #           "key": "alexkovtunov",
      #           "accountId": "5bb53900210f980c53dcbb0f",
      #           "emailAddress": "alexkovtunov@scalefactor.com",
      #           "avatarUrls": {
      #             "48x48": "https://avatar-cdn.atlassian.com/8fa90a0c6355a343b61ccb0f3426e43a?s=48&d=https%3A%2F%2Fsecure.gravatar.com%2Favatar%2F8fa90a0c6355a343b61ccb0f3426e43a%3Fd%3Dmm%26s%3D48%26noRedirect%3Dtrue",
      #             "24x24": "https://avatar-cdn.atlassian.com/8fa90a0c6355a343b61ccb0f3426e43a?s=24&d=https%3A%2F%2Fsecure.gravatar.com%2Favatar%2F8fa90a0c6355a343b61ccb0f3426e43a%3Fd%3Dmm%26s%3D24%26noRedirect%3Dtrue",
      #             "16x16": "https://avatar-cdn.atlassian.com/8fa90a0c6355a343b61ccb0f3426e43a?s=16&d=https%3A%2F%2Fsecure.gravatar.com%2Favatar%2F8fa90a0c6355a343b61ccb0f3426e43a%3Fd%3Dmm%26s%3D16%26noRedirect%3Dtrue",
      #             "32x32": "https://avatar-cdn.atlassian.com/8fa90a0c6355a343b61ccb0f3426e43a?s=32&d=https%3A%2F%2Fsecure.gravatar.com%2Favatar%2F8fa90a0c6355a343b61ccb0f3426e43a%3Fd%3Dmm%26s%3D32%26noRedirect%3Dtrue"
      #           },
      #           "displayName": "Alex Kovtunov",
      #           "active": true,
      #           "timeZone": "Africa/Ceuta",
      #           "accountType": "atlassian"
      #         },
      #         "body": " !screenshot-1.png|thumbnail! \r\nThis is select\\deselect tool, right? so it’s already done\r\n\r\nSo we are adding the table with statuses and errors (kinda like we have Jenkins or CircleCI statistics) here\r\n !screenshot-2.png|thumbnail! ",
      #         "updateAuthor": {
      #           "self": "https://scalefactor.atlassian.net/rest/api/2/user?accountId=5bb53900210f980c53dcbb0f",
      #           "name": "alexkovtunov",
      #           "key": "alexkovtunov",
      #           "accountId": "5bb53900210f980c53dcbb0f",
      #           "emailAddress": "alexkovtunov@scalefactor.com",
      #           "avatarUrls": {
      #             "48x48": "https://avatar-cdn.atlassian.com/8fa90a0c6355a343b61ccb0f3426e43a?s=48&d=https%3A%2F%2Fsecure.gravatar.com%2Favatar%2F8fa90a0c6355a343b61ccb0f3426e43a%3Fd%3Dmm%26s%3D48%26noRedirect%3Dtrue",
      #             "24x24": "https://avatar-cdn.atlassian.com/8fa90a0c6355a343b61ccb0f3426e43a?s=24&d=https%3A%2F%2Fsecure.gravatar.com%2Favatar%2F8fa90a0c6355a343b61ccb0f3426e43a%3Fd%3Dmm%26s%3D24%26noRedirect%3Dtrue",
      #             "16x16": "https://avatar-cdn.atlassian.com/8fa90a0c6355a343b61ccb0f3426e43a?s=16&d=https%3A%2F%2Fsecure.gravatar.com%2Favatar%2F8fa90a0c6355a343b61ccb0f3426e43a%3Fd%3Dmm%26s%3D16%26noRedirect%3Dtrue",
      #             "32x32": "https://avatar-cdn.atlassian.com/8fa90a0c6355a343b61ccb0f3426e43a?s=32&d=https%3A%2F%2Fsecure.gravatar.com%2Favatar%2F8fa90a0c6355a343b61ccb0f3426e43a%3Fd%3Dmm%26s%3D32%26noRedirect%3Dtrue"
      #           },
      #           "displayName": "Alex Kovtunov",
      #           "active": true,
      #           "timeZone": "Africa/Ceuta",
      #           "accountType": "atlassian"
      #         },
      #         "created": "2019-06-04T08:03:14.269-0500",
      #         "updated": "2019-06-04T08:03:14.269-0500",
      #         "jsdPublic": true
      #       }, {
      #         "self": "https://scalefactor.atlassian.net/rest/api/2/issue/21317/comment/20856",
      #         "id": "20856",
      #         "author": {
      #           "self": "https://scalefactor.atlassian.net/rest/api/2/user?accountId=5bb53900210f980c53dcbb0f",
      #           "name": "alexkovtunov",
      #           "key": "alexkovtunov",
      #           "accountId": "5bb53900210f980c53dcbb0f",
      #           "emailAddress": "alexkovtunov@scalefactor.com",
      #           "avatarUrls": {
      #             "48x48": "https://avatar-cdn.atlassian.com/8fa90a0c6355a343b61ccb0f3426e43a?s=48&d=https%3A%2F%2Fsecure.gravatar.com%2Favatar%2F8fa90a0c6355a343b61ccb0f3426e43a%3Fd%3Dmm%26s%3D48%26noRedirect%3Dtrue",
      #             "24x24": "https://avatar-cdn.atlassian.com/8fa90a0c6355a343b61ccb0f3426e43a?s=24&d=https%3A%2F%2Fsecure.gravatar.com%2Favatar%2F8fa90a0c6355a343b61ccb0f3426e43a%3Fd%3Dmm%26s%3D24%26noRedirect%3Dtrue",
      #             "16x16": "https://avatar-cdn.atlassian.com/8fa90a0c6355a343b61ccb0f3426e43a?s=16&d=https%3A%2F%2Fsecure.gravatar.com%2Favatar%2F8fa90a0c6355a343b61ccb0f3426e43a%3Fd%3Dmm%26s%3D16%26noRedirect%3Dtrue",
      #             "32x32": "https://avatar-cdn.atlassian.com/8fa90a0c6355a343b61ccb0f3426e43a?s=32&d=https%3A%2F%2Fsecure.gravatar.com%2Favatar%2F8fa90a0c6355a343b61ccb0f3426e43a%3Fd%3Dmm%26s%3D32%26noRedirect%3Dtrue"
      #           },
      #           "displayName": "Alex Kovtunov",
      #           "active": true,
      #           "timeZone": "Africa/Ceuta",
      #           "accountType": "atlassian"
      #         },
      #         "body": "How many last syncs do we show?",
      #         "updateAuthor": {
      #           "self": "https://scalefactor.atlassian.net/rest/api/2/user?accountId=5bb53900210f980c53dcbb0f",
      #           "name": "alexkovtunov",
      #           "key": "alexkovtunov",
      #           "accountId": "5bb53900210f980c53dcbb0f",
      #           "emailAddress": "alexkovtunov@scalefactor.com",
      #           "avatarUrls": {
      #             "48x48": "https://avatar-cdn.atlassian.com/8fa90a0c6355a343b61ccb0f3426e43a?s=48&d=https%3A%2F%2Fsecure.gravatar.com%2Favatar%2F8fa90a0c6355a343b61ccb0f3426e43a%3Fd%3Dmm%26s%3D48%26noRedirect%3Dtrue",
      #             "24x24": "https://avatar-cdn.atlassian.com/8fa90a0c6355a343b61ccb0f3426e43a?s=24&d=https%3A%2F%2Fsecure.gravatar.com%2Favatar%2F8fa90a0c6355a343b61ccb0f3426e43a%3Fd%3Dmm%26s%3D24%26noRedirect%3Dtrue",
      #             "16x16": "https://avatar-cdn.atlassian.com/8fa90a0c6355a343b61ccb0f3426e43a?s=16&d=https%3A%2F%2Fsecure.gravatar.com%2Favatar%2F8fa90a0c6355a343b61ccb0f3426e43a%3Fd%3Dmm%26s%3D16%26noRedirect%3Dtrue",
      #             "32x32": "https://avatar-cdn.atlassian.com/8fa90a0c6355a343b61ccb0f3426e43a?s=32&d=https%3A%2F%2Fsecure.gravatar.com%2Favatar%2F8fa90a0c6355a343b61ccb0f3426e43a%3Fd%3Dmm%26s%3D32%26noRedirect%3Dtrue"
      #           },
      #           "displayName": "Alex Kovtunov",
      #           "active": true,
      #           "timeZone": "Africa/Ceuta",
      #           "accountType": "atlassian"
      #         },
      #         "created": "2019-06-04T08:12:40.081-0500",
      #         "updated": "2019-06-04T08:12:40.081-0500",
      #         "jsdPublic": true
      #       }, {
      #         "self": "https://scalefactor.atlassian.net/rest/api/2/issue/21317/comment/20857",
      #         "id": "20857",
      #         "author": {
      #           "self": "https://scalefactor.atlassian.net/rest/api/2/user?accountId=5bb53900210f980c53dcbb0f",
      #           "name": "alexkovtunov",
      #           "key": "alexkovtunov",
      #           "accountId": "5bb53900210f980c53dcbb0f",
      #           "emailAddress": "alexkovtunov@scalefactor.com",
      #           "avatarUrls": {
      #             "48x48": "https://avatar-cdn.atlassian.com/8fa90a0c6355a343b61ccb0f3426e43a?s=48&d=https%3A%2F%2Fsecure.gravatar.com%2Favatar%2F8fa90a0c6355a343b61ccb0f3426e43a%3Fd%3Dmm%26s%3D48%26noRedirect%3Dtrue",
      #             "24x24": "https://avatar-cdn.atlassian.com/8fa90a0c6355a343b61ccb0f3426e43a?s=24&d=https%3A%2F%2Fsecure.gravatar.com%2Favatar%2F8fa90a0c6355a343b61ccb0f3426e43a%3Fd%3Dmm%26s%3D24%26noRedirect%3Dtrue",
      #             "16x16": "https://avatar-cdn.atlassian.com/8fa90a0c6355a343b61ccb0f3426e43a?s=16&d=https%3A%2F%2Fsecure.gravatar.com%2Favatar%2F8fa90a0c6355a343b61ccb0f3426e43a%3Fd%3Dmm%26s%3D16%26noRedirect%3Dtrue",
      #             "32x32": "https://avatar-cdn.atlassian.com/8fa90a0c6355a343b61ccb0f3426e43a?s=32&d=https%3A%2F%2Fsecure.gravatar.com%2Favatar%2F8fa90a0c6355a343b61ccb0f3426e43a%3Fd%3Dmm%26s%3D32%26noRedirect%3Dtrue"
      #           },
      #           "displayName": "Alex Kovtunov",
      #           "active": true,
      #           "timeZone": "Africa/Ceuta",
      #           "accountType": "atlassian"
      #         },
      #         "body": "And if its one common table for all the accounts, then \n\n* should I just show X recent syncs for all the accounts \n\nOR\n\n* should I just show all the accounts and recent sync for each\n\n?",
      #         "updateAuthor": {
      #           "self": "https://scalefactor.atlassian.net/rest/api/2/user?accountId=5bb53900210f980c53dcbb0f",
      #           "name": "alexkovtunov",
      #           "key": "alexkovtunov",
      #           "accountId": "5bb53900210f980c53dcbb0f",
      #           "emailAddress": "alexkovtunov@scalefactor.com",
      #           "avatarUrls": {
      #             "48x48": "https://avatar-cdn.atlassian.com/8fa90a0c6355a343b61ccb0f3426e43a?s=48&d=https%3A%2F%2Fsecure.gravatar.com%2Favatar%2F8fa90a0c6355a343b61ccb0f3426e43a%3Fd%3Dmm%26s%3D48%26noRedirect%3Dtrue",
      #             "24x24": "https://avatar-cdn.atlassian.com/8fa90a0c6355a343b61ccb0f3426e43a?s=24&d=https%3A%2F%2Fsecure.gravatar.com%2Favatar%2F8fa90a0c6355a343b61ccb0f3426e43a%3Fd%3Dmm%26s%3D24%26noRedirect%3Dtrue",
      #             "16x16": "https://avatar-cdn.atlassian.com/8fa90a0c6355a343b61ccb0f3426e43a?s=16&d=https%3A%2F%2Fsecure.gravatar.com%2Favatar%2F8fa90a0c6355a343b61ccb0f3426e43a%3Fd%3Dmm%26s%3D16%26noRedirect%3Dtrue",
      #             "32x32": "https://avatar-cdn.atlassian.com/8fa90a0c6355a343b61ccb0f3426e43a?s=32&d=https%3A%2F%2Fsecure.gravatar.com%2Favatar%2F8fa90a0c6355a343b61ccb0f3426e43a%3Fd%3Dmm%26s%3D32%26noRedirect%3Dtrue"
      #           },
      #           "displayName": "Alex Kovtunov",
      #           "active": true,
      #           "timeZone": "Africa/Ceuta",
      #           "accountType": "atlassian"
      #         },
      #         "created": "2019-06-04T08:13:25.648-0500",
      #         "updated": "2019-06-04T08:14:58.825-0500",
      #         "jsdPublic": true
      #       }, {
      #         "self": "https://scalefactor.atlassian.net/rest/api/2/issue/21317/comment/20862",
      #         "id": "20862",
      #         "author": {
      #           "self": "https://scalefactor.atlassian.net/rest/api/2/user?accountId=5bb53900210f980c53dcbb0f",
      #           "name": "alexkovtunov",
      #           "key": "alexkovtunov",
      #           "accountId": "5bb53900210f980c53dcbb0f",
      #           "emailAddress": "alexkovtunov@scalefactor.com",
      #           "avatarUrls": {
      #             "48x48": "https://avatar-cdn.atlassian.com/8fa90a0c6355a343b61ccb0f3426e43a?s=48&d=https%3A%2F%2Fsecure.gravatar.com%2Favatar%2F8fa90a0c6355a343b61ccb0f3426e43a%3Fd%3Dmm%26s%3D48%26noRedirect%3Dtrue",
      #             "24x24": "https://avatar-cdn.atlassian.com/8fa90a0c6355a343b61ccb0f3426e43a?s=24&d=https%3A%2F%2Fsecure.gravatar.com%2Favatar%2F8fa90a0c6355a343b61ccb0f3426e43a%3Fd%3Dmm%26s%3D24%26noRedirect%3Dtrue",
      #             "16x16": "https://avatar-cdn.atlassian.com/8fa90a0c6355a343b61ccb0f3426e43a?s=16&d=https%3A%2F%2Fsecure.gravatar.com%2Favatar%2F8fa90a0c6355a343b61ccb0f3426e43a%3Fd%3Dmm%26s%3D16%26noRedirect%3Dtrue",
      #             "32x32": "https://avatar-cdn.atlassian.com/8fa90a0c6355a343b61ccb0f3426e43a?s=32&d=https%3A%2F%2Fsecure.gravatar.com%2Favatar%2F8fa90a0c6355a343b61ccb0f3426e43a%3Fd%3Dmm%26s%3D32%26noRedirect%3Dtrue"
      #           },
      #           "displayName": "Alex Kovtunov",
      #           "active": true,
      #           "timeZone": "Africa/Ceuta",
      #           "accountType": "atlassian"
      #         },
      #         "body": "Agreed with [~accountid:5ad61d2fe378d62b3bb3ffbc] to separate (1) into different tickets that I can do right after this one",
      #         "updateAuthor": {
      #           "self": "https://scalefactor.atlassian.net/rest/api/2/user?accountId=5bb53900210f980c53dcbb0f",
      #           "name": "alexkovtunov",
      #           "key": "alexkovtunov",
      #           "accountId": "5bb53900210f980c53dcbb0f",
      #           "emailAddress": "alexkovtunov@scalefactor.com",
      #           "avatarUrls": {
      #             "48x48": "https://avatar-cdn.atlassian.com/8fa90a0c6355a343b61ccb0f3426e43a?s=48&d=https%3A%2F%2Fsecure.gravatar.com%2Favatar%2F8fa90a0c6355a343b61ccb0f3426e43a%3Fd%3Dmm%26s%3D48%26noRedirect%3Dtrue",
      #             "24x24": "https://avatar-cdn.atlassian.com/8fa90a0c6355a343b61ccb0f3426e43a?s=24&d=https%3A%2F%2Fsecure.gravatar.com%2Favatar%2F8fa90a0c6355a343b61ccb0f3426e43a%3Fd%3Dmm%26s%3D24%26noRedirect%3Dtrue",
      #             "16x16": "https://avatar-cdn.atlassian.com/8fa90a0c6355a343b61ccb0f3426e43a?s=16&d=https%3A%2F%2Fsecure.gravatar.com%2Favatar%2F8fa90a0c6355a343b61ccb0f3426e43a%3Fd%3Dmm%26s%3D16%26noRedirect%3Dtrue",
      #             "32x32": "https://avatar-cdn.atlassian.com/8fa90a0c6355a343b61ccb0f3426e43a?s=32&d=https%3A%2F%2Fsecure.gravatar.com%2Favatar%2F8fa90a0c6355a343b61ccb0f3426e43a%3Fd%3Dmm%26s%3D32%26noRedirect%3Dtrue"
      #           },
      #           "displayName": "Alex Kovtunov",
      #           "active": true,
      #           "timeZone": "Africa/Ceuta",
      #           "accountType": "atlassian"
      #         },
      #         "created": "2019-06-04T09:29:04.079-0500",
      #         "updated": "2019-06-04T09:29:18.700-0500",
      #         "jsdPublic": true
      #       }, {
      #         "self": "https://scalefactor.atlassian.net/rest/api/2/issue/21317/comment/21390",
      #         "id": "21390",
      #         "author": {
      #           "self": "https://scalefactor.atlassian.net/rest/api/2/user?accountId=5bb53900210f980c53dcbb0f",
      #           "name": "alexkovtunov",
      #           "key": "alexkovtunov",
      #           "accountId": "5bb53900210f980c53dcbb0f",
      #           "emailAddress": "alexkovtunov@scalefactor.com",
      #           "avatarUrls": {
      #             "48x48": "https://avatar-cdn.atlassian.com/8fa90a0c6355a343b61ccb0f3426e43a?s=48&d=https%3A%2F%2Fsecure.gravatar.com%2Favatar%2F8fa90a0c6355a343b61ccb0f3426e43a%3Fd%3Dmm%26s%3D48%26noRedirect%3Dtrue",
      #             "24x24": "https://avatar-cdn.atlassian.com/8fa90a0c6355a343b61ccb0f3426e43a?s=24&d=https%3A%2F%2Fsecure.gravatar.com%2Favatar%2F8fa90a0c6355a343b61ccb0f3426e43a%3Fd%3Dmm%26s%3D24%26noRedirect%3Dtrue",
      #             "16x16": "https://avatar-cdn.atlassian.com/8fa90a0c6355a343b61ccb0f3426e43a?s=16&d=https%3A%2F%2Fsecure.gravatar.com%2Favatar%2F8fa90a0c6355a343b61ccb0f3426e43a%3Fd%3Dmm%26s%3D16%26noRedirect%3Dtrue",
      #             "32x32": "https://avatar-cdn.atlassian.com/8fa90a0c6355a343b61ccb0f3426e43a?s=32&d=https%3A%2F%2Fsecure.gravatar.com%2Favatar%2F8fa90a0c6355a343b61ccb0f3426e43a%3Fd%3Dmm%26s%3D32%26noRedirect%3Dtrue"
      #           },
      #           "displayName": "Alex Kovtunov",
      #           "active": true,
      #           "timeZone": "Africa/Ceuta",
      #           "accountType": "atlassian"
      #         },
      #         "body": "[~kennyjohnson] please check if we still will need to select a specific bank account(s) for asset report to download?\r\nthis needs to be checked and repointed ",
      #         "updateAuthor": {
      #           "self": "https://scalefactor.atlassian.net/rest/api/2/user?accountId=5bb53900210f980c53dcbb0f",
      #           "name": "alexkovtunov",
      #           "key": "alexkovtunov",
      #           "accountId": "5bb53900210f980c53dcbb0f",
      #           "emailAddress": "alexkovtunov@scalefactor.com",
      #           "avatarUrls": {
      #             "48x48": "https://avatar-cdn.atlassian.com/8fa90a0c6355a343b61ccb0f3426e43a?s=48&d=https%3A%2F%2Fsecure.gravatar.com%2Favatar%2F8fa90a0c6355a343b61ccb0f3426e43a%3Fd%3Dmm%26s%3D48%26noRedirect%3Dtrue",
      #             "24x24": "https://avatar-cdn.atlassian.com/8fa90a0c6355a343b61ccb0f3426e43a?s=24&d=https%3A%2F%2Fsecure.gravatar.com%2Favatar%2F8fa90a0c6355a343b61ccb0f3426e43a%3Fd%3Dmm%26s%3D24%26noRedirect%3Dtrue",
      #             "16x16": "https://avatar-cdn.atlassian.com/8fa90a0c6355a343b61ccb0f3426e43a?s=16&d=https%3A%2F%2Fsecure.gravatar.com%2Favatar%2F8fa90a0c6355a343b61ccb0f3426e43a%3Fd%3Dmm%26s%3D16%26noRedirect%3Dtrue",
      #             "32x32": "https://avatar-cdn.atlassian.com/8fa90a0c6355a343b61ccb0f3426e43a?s=32&d=https%3A%2F%2Fsecure.gravatar.com%2Favatar%2F8fa90a0c6355a343b61ccb0f3426e43a%3Fd%3Dmm%26s%3D32%26noRedirect%3Dtrue"
      #           },
      #           "displayName": "Alex Kovtunov",
      #           "active": true,
      #           "timeZone": "Africa/Ceuta",
      #           "accountType": "atlassian"
      #         },
      #         "created": "2019-06-17T13:11:45.063-0500",
      #         "updated": "2019-06-17T13:11:45.063-0500",
      #         "jsdPublic": true
      #       }],
      #       "maxResults": 7,
      #       "total": 7,
      #       "startAt": 0
      #     },
      #     "worklog": {
      #       "startAt": 0,
      #       "maxResults": 20,
      #       "total": 0,
      #       "worklogs": []
      #     }
      #   }
      # }, ....
      # ]

      unless sprint_id.nil?
        process_paginated(:issues_for_sprint, { board_id: board_id, sprint_id: sprint_id })
      else
        process_paginated(:issues_for_board, { board_id: board_id })
      end
    end

    def list_velocities(board_id)
      # Sample response:
      # {
      #   "sprints": [{
      #     "id": 177,
      #     "sequence": 177,
      #     "name": "BP Sprint 7 2019",
      #     "state": "CLOSED",
      #     "linkedPagesCount": 0,
      #     "goal": "Deploy Dwolla IAV\nComplete Portal Bill Details Redesign"
      #   }, {
      #     "id": 164,
      #     "sequence": 164,
      #     "name": "BP Sprint 6 2019",
      #     "state": "CLOSED",
      #     "linkedPagesCount": 0,
      #     "goal": ""
      #   },
      #   ...
      #   }],
      #   "velocityStatEntries": {
      #     "177": {
      #       "estimated": {
      #         "value": 26.0,
      #         "text": "26.0"
      #       },
      #       "completed": {
      #         "value": 23.0,
      #         "text": "23.0"
      #       }
      #     },
      #     "164": {
      #       "estimated": {
      #         "value": 18.0,
      #         "text": "18.0"
      #       },
      #       "completed": {
      #         "value": 31.0,
      #         "text": "31.0"
      #       }
      #     },
      #     ...
      #   }
      # }
      response = process_request(:velocities_for_board, { board_id: board_id })
      response
    end

    def process_paginated(uri, params = {})
      page = 0
      max_results = 50
      response = nil
      values = []
      finished = false
      while(!finished)
        response = process_request(uri, params.merge(page: page, max_results: max_results))
        values += response["values"] if response["values"]
        values += response["issues"] if response["issues"]
        max_results = response["maxResults"]
        page += 1
        if(response.has_key?("isLast"))
          finished = response["isLast"]
        else
          # puts "processing at #{values.length} out of #{response["total"]}"
          finished = response["total"] <= values.length
        end
      end
      values
    end

    def process_request(uri_identifier, params = {})
      uri = construct_uri(uri_identifier, params)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      request = Net::HTTP::Get.new(uri.request_uri)
      request.basic_auth(@username, @api_key)
      response_body = http.request(request).body
      JSON.parse(response_body)
    end

    def construct_uri(uri_identifier, params)
      page = params.delete(:page)
      page_size = params.delete(:max_results)
      uri = URI.parse(@host + (ROUTES[uri_identifier] % params))
      uri.query = URI.encode_www_form({ startAt: page * page_size, maxResults: page_size }) if((!page.nil?) && page_size)
      uri
    end
  end
end
