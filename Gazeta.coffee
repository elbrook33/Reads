###
# Reads - a shared database of good articles.
#
# To do:
# - Optimising?
###


#### Databases ####

Feeds = new Mongo.Collection "DB_Feeds"
Articles = new Mongo.Collection "DB_Articles"
Histories = new Mongo.Collection "DB_Histories"
Bookmarks = new Mongo.Collection "DB_Bookmarks"


###
# ===========
# Client-side
# ===========
###

#### Client app ####

if Meteor.isClient

   # ================
   # Top-level set up
   # ================

   Template.body.onCreated ->
      this.subscribe "Data_Feeds"
      this.subscribe "Data_Bookmarks"
      this.subscribe "Data_Histories"
      this.subscribe "Data_Articles"

   Template.body.helpers
      Filtering:  -> "filtering" if Session.get "Filter"
      Focus:      -> Session.get "Focus"
      ReaderOpen: -> "reader-open" if Session.get("ShowReader") and Session.get("Focus") == "ArticlesList"

   # =========
   # FeedsList
   # =========

   ## Templates ##

   Template.FeedsList.helpers
      FilterBest:       -> Contains("Best", Session.get "Filter") or GetBestArticles()
      TripleBookmarked: -> FilterFeeds GetFeeds GetBookmarks 3
      DoubleBookmarked: -> FilterFeeds GetFeeds GetBookmarks 2
      SingleBookmarked: -> FilterFeeds GetFeeds GetBookmarks 1
      Others:           -> FilterFeeds OtherFeeds GetAllBookmarks()

   # -------------
   # FeedsListItem
   # -------------

   ## Templates ##

   Template.FeedsListItem.helpers
      IsSelected:     -> Session.get("SelectedFeed") == @_id
      IsFocused:      -> Session.get("SelectedFeed") == @_id and Session.get("Focus") == "FeedsList"
      IsBookmarked:   -> BookmarkLevel(@_id) > 0
      SampleArticles: -> Limit 2, FilterArticles Articles.find({Feed: @_id}, sort: Date: -1).fetch()
      Stars:          -> BuildStars GetFeedRating @_id
      FormattedDate:  -> FormatDate(@Date, Session.get "TimeUpdate")

   Template.BestListItem.helpers
      IsSelected:     -> Session.get("SelectedFeed") == "best"
      IsFocused:      -> Session.get("SelectedFeed") == "best" and Session.get("Focus") == "FeedsList"
      SampleArticles: -> Limit 2, GetBestArticles()
      Unread:         -> FilterArticlesArray(BestArticles AllRead()).length

   Template.FeedsListArticleItem.helpers
      IsRead: -> Histories.findOne(User: Meteor.userId(), Article: @_id)?

   ## Events ##

   Template.FeedsListItem.events
      "click .feed": ->
         SetFeed @_id
         SetArticle 0
         Session.set "Focus", "ArticlesList"
         Session.set "ShowReader", false
         return
      "click .feed-info": ->
         SetBookmarkLevel ((BookmarkLevel(@_id)+1) % 4), @_id
         false

   Template.BestListItem.events
      "click .feed": ->
         SetFeed "best"
         SetArticle 0
         Session.set "Focus", "ArticlesList"
         Session.set "ShowReader", false
         return

   # ================
   # ArticlesListItem
   # ================

   ## Templates ##

   Template.ArticlesList.helpers
      SelectionArticles: -> GetArticles()

   Template.ArticlesListItem.helpers
      Stars:           -> BuildStars GetArticleRating @_id, @Rating
      FormattedDate:   -> FormatDate(@Date, Session.get "TimeUpdate")
      FormattedAuthor: ->
         if Session.get("SelectedFeed") == "best"
            Pub = "<i>" + Feeds.findOne(@Feed).Title + "</i>"
            if !@Author then return Pub else return @Author + ", " + Pub
         @Author

      IsSelected: -> Session.get("SelectedArticle") == IndexOfID(@_id)
      IsFocused:  -> Session.get("SelectedArticle") == IndexOfID(@_id) and
                     Session.get("Focus") == "ArticlesList"
      IsRead:     -> Histories.findOne(User: Meteor.userId(), Article: @_id)?
      HasRated:   -> MyArticleRating(@_id)?

   ## Events ##

   Template.ArticlesListItem.events
      "click .date": (event) ->
         Meteor.call "MarkRead", @_id, (GetMyArticleRating(@_id)+1) % 4
         false

      "click .article": (event) ->
         Meteor.call "MarkRead", @_id
         if CurrentArticleID() == @_id and Session.get("Focus") == "ArticlesList"
            ToggleReader()
         else
            SetArticle IndexOfID @_id
            ShowReader()
         Session.set "Focus", "ArticlesList"
         false

   # ======
   # Reader
   # ======

   Template.Reader.helpers
      CurrentArticle: -> GetCurrentArticle().Link if Session.get "ShowReader"

   # =====
   # Popup
   # =====

   Template.body.events
      "click #popup-inner>div": -> return false
      "click #popup":  -> HidePopup(); return
      "click #center, click #right": -> ToggleFocus(); return

      "click #search-button": -> ShowPopup(); ShowSearch(); return false
      "click #add-button":    -> ShowPopup(); ShowAdd()   ; return false
      "click #help-button":   -> ShowPopup(); ShowHelp()  ; return false
      "click #login-button":  -> ShowPopup(); ShowLogin() ; return false

   Template.Popup.events
      "keyup #search-box": (event) ->
         if event.keyCode == 13 then $("input").blur(); $("#popup").fadeOut(); return
         Session.set "Filter", $("#search-box").val()
         return

      "submit #add-form": ->
         Meteor.call "AddFeed", $("#add-box").val()
         $("#add-box").val("")
         false

   # ======
   # Config
   # ======

   Accounts.ui.config passwordSignupFields: "USERNAME_ONLY"

   # =======
   # General
   # =======

   Meteor.startup ->
      Session.setDefault "Focus", "FeedsList"
      Session.setDefault "SelectedFeed", "best"
      Session.setDefault "SelectedArticle", 0
      UpdateTime()

      # ---------------
      # Keyboard events
      # ---------------

      $(document).on "keydown", (event) ->
         if event.keyCode == 27 # Escape key
            HidePopup()
            ClearSearch()
            Session.set "ShowReader", false
         if $(":focus").length then return # If an input field has focus, let it do its thing.
         switch event.keyCode
            when  9 then ToggleFocus(); return false # Tab key. Cycle focus.
            when 65 then TogglePopup(); ShowAdd()
            when 70 then TogglePopup(); ShowSearch()
            when 72 then TogglePopup(); ShowHelp()
            when 76 then TogglePopup(); ShowLogin()
            when  80 then console.log GetCurrentArticle()
            when  82 then Meteor.call "UpdateAllFeeds"
            when 220 then Meteor.call "ResetAll"
         switch Session.get "Focus"
            when "FeedsList"
               switch event.keyCode
                  when 38 then IncrementFeed(-1); return false
                  when 40 then IncrementFeed( 1); return false
                  when 48 then SetBookmarkLevel(0)
                  when 49 then SetBookmarkLevel(1)
                  when 50 then SetBookmarkLevel(2)
                  when 51 then SetBookmarkLevel(3)
            when "ArticlesList"
               switch event.keyCode
                  when 38 then IncrementArticle(-1); return false
                  when 40 then IncrementArticle( 1); return false
                  when  8 then MarkCurrentRead( )
                  when 48 then MarkCurrentRead(0)
                  when 49 then MarkCurrentRead(1)
                  when 50 then MarkCurrentRead(2)
                  when 51 then MarkCurrentRead(3)
                  when 13 then OpenArticle(); return false
                  when 32 then OpenArticle(); return false
         return
      return

   # ================
   # Helper functions
   # ================

   # ------------
   # UI functions
   # ------------

   #### Feeds and articles ####

   ToggleFocus = ->
      if Session.get("Focus") == "FeedsList"
         Session.set "Focus", "ArticlesList"
      else
         Session.set "Focus", "FeedsList"
      return

   IncrementFeed = (n) ->
      Index = $("#"+Session.get "SelectedFeed").index(".feed") + n
      Index = FitToBounds Index, 0, $(".feed").length-1
      SetFeed $(".feed").get(Index).id
      SetArticle 0
      ScrollToFit Session.get("SelectedFeed"), "left"
      return

   IncrementArticle = (n) ->
      Index = Session.get("SelectedArticle") + n
      Index = FitToBounds Index, 0, MaxIndex()
      SetArticle Index
      if Session.get "ShowReader" then MarkCurrentRead()
      ScrollToFit IDatIndex(Index), "right"
      return

   ScrollToFit = (ElemID, WrapID) ->
      Elem = $("#"+ElemID)
      if Elem.offset().top < 0
         Wrap = $("#"+WrapID+" .container")
         Wrap.scrollTop( Wrap.scrollTop() + Elem.offset().top )
      else
         Wrap = $("#"+WrapID+" .container")
         Height = $("#"+WrapID).height()
         if Elem.offset().top + Elem.outerHeight() > Height
            Delta = Elem.offset().top + Elem.outerHeight() - Height
            Wrap.scrollTop( Wrap.scrollTop() + Delta )

   #### Stars and other details ####

   BuildStars = (RawRating) ->
      Rating = if RawRating? then Math.round(RawRating) else 0
      Filled = (('★' for i in [1..Rating]) if Rating > 0) ? []
      Hollow = (('☆' for i in [2..Rating]) if Rating < 3) ? []
      Filled.join("") + Hollow.join("")

   UpdateTime = () ->
      Session.set "TimeUpdate", new Date().toString()
      Meteor.setTimeout UpdateTime, 30 * 60 * 1000
      return

   #### Popups (including search) ####

   HidePopup = -> $("input").blur(); $("#popup").fadeOut(); return
   ShowPopup = -> $("#popup").fadeIn() ; return
   TogglePopup = -> $("#popup").toggle()

   ShowSearch = ->
      $("#popup-inner>div").hide()
      $("#search").show 100, -> $("#search-box").focus()
      return
   ShowAdd = ->
      $("#popup-inner>div").hide()
      $("#add").show 100, -> $("#add-box").focus()
      return
   ShowHelp  = -> $("#popup-inner>div").hide(); $("#help" ).show(); return
   ShowLogin = -> $("#popup-inner>div").hide(); $("#login").show(); return

   ClearSearch = ->
      Session.set "Filter", null
      $("#search-box").val ""

   #### Reader ####

   ToggleReader = ->
      if Session.get "ShowReader"
         Session.set "ShowReader", false
      else
         ShowReader()

   ShowReader = ->
      if GetCurrentArticle().Embed and !Meteor.Device.isPhone()
         Session.set "ShowReader", true
      else
         window.open GetCurrentArticle().Link

   OpenArticle = ->
      ToggleReader()
      MarkCurrentRead()

   #### Setting session states ####

   SetFeed = (ID) ->
      Session.set "ShowReader", false
      Session.set "SelectedFeed", ID

   SetArticle = (Index) ->
      $("#reader-iframe").attr "src", "about:blank"
      Session.set "SelectedArticle", Index

   # --------------
   # Filtering data
   # --------------

   #### Feeds ####

   GetBookmarks =  (n) -> Bookmarks.find(User: Meteor.userId(), Level: n).map (x) -> x.Feed
   GetAllBookmarks =   -> Bookmarks.find(User: Meteor.userId()).map           (x) -> x.Feed
   GetFeeds   = (list) -> Feeds.find( {_id:  $in: list}, sort:  Date: -1              ).fetch()
   OtherFeeds = (list) -> Feeds.find( {_id: $nin: list}, sort: {Rating: -1, Date: -1} ).fetch()

   FilterFeeds = (Feeds) ->
      Feeds.filter (f) -> Contains(f.Title, Session.get "Filter") or
                          FilterArticles(AllArticles f._id).length

   GetFeedRating = (FeedID) ->
      Bookmark = BookmarkLevel FeedID
      if Bookmark > 0
         return Bookmark
      else
         return Feeds.findOne(FeedID).Rating

   BookmarkLevel = (FeedID) ->
      (Bookmarks.findOne(User: Meteor.userId(), Feed: FeedID) ? {Level: 0}).Level

   #### Articles ####

   GetArticles =     -> FilterArticles AllArticles()
   GetBestArticles = -> FilterArticles BestArticles []

   AllArticles = (FeedID) ->
      if !FeedID? and Session.get("SelectedFeed") == "best" then return BestArticles []
      FeedID = Session.get "SelectedFeed" if !FeedID?
      Articles.find( {Feed: FeedID}, sort: {Date: -1}, limit: 20 ).fetch()

   BestArticles = (Exclude) ->
      Articles.find( {_id: {$nin: Exclude}, Rating: {$gt: 2}}, sort: Date: -1 ).fetch()

   FilterArticles = (List, Query = Session.get "Filter") ->
      List.filter (Article) ->
         Contains(Article.Title,   Query) or
         Contains(Article.Author,  Query) or
         Contains(Article.Summary, Query)

   AllRead = ->
      Histories.find(User: Meteor.userId()).map (x) -> x.Article

   GetArticleRating = (ArticleID, Rating) -> MyArticleRating(ArticleID) ? Rating
   GetMyArticleRating = (ArticleID)       -> MyArticleRating(ArticleID) ? 0
   MyArticleRating    = (ArticleID)       ->
      History = Histories.findOne {User: Meteor.userId(), Article: ArticleID}
      if History? then return History.Rating else return null

   IndexOfID = (ID)    -> GetArticles().map( (i) -> i._id ).indexOf ID
   MaxIndex  =         -> GetArticles().length - 1
   IDatIndex = (Index) -> GetArticleByIndex(Index)._id
   CurrentArticleID  = -> GetCurrentArticle()._id
   GetCurrentArticle = -> GetArticleByIndex Session.get "SelectedArticle"
   GetArticleByIndex = (Index) -> GetArticles()[Index]

   # -----------------
   # Database requests
   # -----------------

   SetBookmarkLevel = (n, FeedID = Session.get "SelectedFeed") ->
      Meteor.call "Bookmark", FeedID, n
      return

   MarkCurrentRead = (RatingValue) ->
      Meteor.call "MarkRead", CurrentArticleID(), RatingValue
      return

###
# ===========
# Server-side
# ===========
###

# ----------
# Server app
# ----------

if Meteor.isServer
  Meteor.startup ->
    Meteor.publish "Data_Feeds", -> Feeds.find {}
    Meteor.publish "Data_Articles", -> Articles.find Date: $gt: new Date(new Date() - 7*24*60*60*1000).toISOString()
    Meteor.publish "Data_Histories", -> Histories.find User: this.userId
    Meteor.publish "Data_Bookmarks", -> Bookmarks.find User: this.userId
    UpdateAll()
    Meteor.setInterval UpdateAll, 10 * 60 * 1000
    return

# -----------------------------------
# Client-Server exchanges ("methods")
# -----------------------------------

Meteor.methods

  #### General ####

  AddFeed: (FeedURL) ->
    UpdateFeed FeedURL
    return

  ResetAll: ->
    Articles.remove {}
    Bookmarks.remove {}
    Histories.remove {}
    return

  UpdateAllFeeds: ->
    UpdateAll()
    return

  #### Feeds ####

  Bookmark: (FeedID, n) ->
    if n == 0
      Bookmarks.remove
        User: Meteor.userId()
        Feed: FeedID
      return
    Previous = Bookmarks.findOne {User: Meteor.userId(), Feed: FeedID}
    if Previous?
      Bookmarks.update {
        User: Meteor.userId()
        Feed: FeedID
      }, $set: Level: n
    else
      Bookmarks.insert
        User: Meteor.userId()
        Feed: FeedID
        Level: n
    return

  #### Articles ####

  MarkRead: (ArticleID, RatingValue) ->
    Previous = Histories.findOne {User: Meteor.userId(), Article: ArticleID}
    if !Previous?
      Histories.insert
        User: Meteor.userId()
        Feed: Articles.findOne(ArticleID).Feed
        Article: ArticleID
        Rating: RatingValue
    else
      NewRating = RatingValue ? Previous.Rating
      Histories.update {
        User: Meteor.userId()
        Article: ArticleID
      }, $set: Rating: NewRating
    # UpdateArticleRating ArticleID
    return

# -----------------------
# Server helper functions
# -----------------------

UpdateAll = ->
  Articles.find().forEach (Article) ->
    UpdateArticleRating Article._id
    return
  Feeds.find().forEach (Feed) ->
    console.log "Updating " + Feed.URL
    UpdateFeed Feed.URL
    return
  return

UpdateFeed = (URL) ->
  # Fetch URL
  RawFeed = HTTP.get("http://ajax.googleapis.com/ajax/services/feed/load?v=1.0&num=10&q=" + URL, HandleFeed)
  return

HandleFeed = (error, result) ->
  if error or result.data.responseStatus != 200
    console.log "Could not load publication. " + error
    return
  FeedData = result.data.responseData.feed

  # Add publication to database (if necessary)
  Title = FeedData.title
  Feed = Feeds.findOne {Title: Title}
  Feed = AddFeed FeedData if !Feed?
  FeedID = Feed._id

  # Add new articles to database (by checking date)
  RSSEntries = FeedData.entries
  LastDate = Feed.Date ? "0"
  for i in RSSEntries
    if new Date(i.publishedDate).toISOString() > LastDate then AddArticle(FeedID, i)

  # Update feed's date and rating
  LastEntry = Articles.findOne({Feed: FeedID}, sort: Date: -1)
  LastDate = if LastEntry? then new Date(LastEntry.Date).toISOString() else "0"

  Ratings = Articles.find(Feed: FeedID).map( (a) -> a.Rating ).filter (x) -> x?
  AverageRating = if Ratings.length then (Ratings.reduce (a,b) -> a+b) / Ratings.length else 0

  console.log( Title + ": " + RSSEntries.length + "x" + AverageRating + "@" + LastDate + " (" + Ratings + ")" );

  Feeds.update FeedID, $set:
    Date: LastDate
    Rating: AverageRating

  return

UpdateArticleRating = (ArticleID) ->
  Ratings = Histories.find(Article: ArticleID).map( (h) -> h.Rating ).filter (x) -> x?
  AverageRating = if Ratings.length then (Ratings.reduce (a,b) -> a+b) / Ratings.length else null
  Articles.update ArticleID, $set: Rating: AverageRating

#### Database helpers ####

AddFeed = (FeedData) ->
  Feeds.insert
    Title:       FeedData.title
    URL:         FeedData.feedUrl
    Link:        FeedData.link
    Description: FeedData.description
  Feeds.findOne Title: FeedData.title

AddArticle = (Feed, Entry) ->
  Author = Entry.author.replace(/\S+@\S+ \W([\w\s]*)\W/, "$1")
  Author = ProperCase(Author)
  newDate = new Date(Entry["publishedDate"]).toISOString()
  Header = HTTP.get(Entry.link, jar: true).headers["x-frame-options"]
  if Header? and (
     Contains Header, "DENY" or
     Contains Header, "SAMEORIGIN" or
     Contains Header, "ALLOW-FROM" )
    CanEmbed = false
  Articles.insert
    Feed:    Feed
    Title:   Entry.title
    Author:  Author
    Date:    newDate
    Link:    Entry.link
    Summary: Entry.contentSnippet
    Text:    Entry.content
    Embed:   CanEmbed ? true
  return


##
# ===============
# Generic helpers
# ===============
##

Limit = (n, List) -> List.slice 0, n
Contains = (Text, Query) -> if Query? then Text.toLowerCase().match(Query.toLowerCase())? else true

FitToBounds = (n, Min, Max) ->
   if n < Min then return Min
   if n > Max then return Max
   n

ProperCase = (Text) ->
   Text.replace /\w+/g, (t) ->
      if t.toLowerCase() == "and"
         "and"
      else
         t.charAt(0).toUpperCase() + t.substr(1).toLowerCase()

FormatDate = (OldDate, NewDate) ->
   ms = new Date(NewDate) - new Date(OldDate)
   if ms > 2*24*60*60*1000 then return Math.floor(ms / 24/60/60/1000) +  " days ago"
   if ms > 1*24*60*60*1000 then return                                   "Yesterday"
   if ms >    2*60*60*1000 then return Math.floor(ms /    60/60/1000) + " hours ago"
   if ms >    1*60*60*1000 then return                                  "1 hour ago"
   "less than 1 hour ago"
