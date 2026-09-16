# 52_check_references.R — check references.bib against Crossref (and PubMed for a PMID)
#
# Usage: Rscript R/52_check_references.R
#
# For each entry, queries Crossref with the title and first author, then compares title, journal,
# year, volume, issue and pages with what the .bib says. Writes outputs/tables/reference_check.csv
# with the fields side by side and a status per entry. Nothing is corrected automatically: the
# output is for the author to review, because a near-miss title can still be the wrong paper.

source(here::here("R", "00_setup.R"))
suppressPackageStartupMessages(library(jsonlite))

bib_file <- here("docs", "manuscript", "references.bib")
raw <- readLines(bib_file, warn = FALSE, encoding = "UTF-8")

# ---- parse the .bib ---------------------------------------------------------------------------
starts <- grep("^@", raw)
ends <- c(tail(starts, -1) - 1, length(raw))
entries <- lapply(seq_along(starts), function(i) {
  block <- raw[starts[i]:ends[i]]
  field <- function(f) {
    ln <- grep(paste0("^\\s*", f, " = \\{"), block)
    if (!length(ln)) return(NA_character_)
    txt <- paste(block[ln:length(block)], collapse = " ")
    txt <- sub(paste0("^\\s*", f, " = \\{"), "", txt)
    sub("\\},?\\s*(\\w+ = \\{.*)?$", "", sub("\\}.*$", "", txt))
  }
  list(key = sub("^@[A-Za-z]+\\{([^,]+),.*$", "\\1", block[1]),
       type = sub("^@([A-Za-z]+)\\{.*$", "\\1", block[1]),
       author = field("author"), title = field("title"), journal = field("journal"),
       year = field("year"), volume = field("volume"), number = field("number"),
       pages = field("pages"))
})

clean <- function(x) {
  x <- gsub("\\{|\\}", "", x)
  x <- gsub("\\\\[a-zA-Z]+\\s*", "", x)   # LaTeX accents
  trimws(gsub("\\s+", " ", x))
}
norm <- function(x) gsub("[^a-z0-9]", "", tolower(clean(x)))

get_json <- function(url) {
  # simplifyVector = FALSE keeps items as a plain list: Crossref omits fields per item, and a
  # simplified data.frame then has ragged columns
  tryCatch(fromJSON(url, simplifyVector = FALSE), error = function(e) NULL)
}
pick <- function(x, field) {
  v <- x[[field]]
  if (is.null(v) || !length(v)) return(NA_character_)
  if (is.list(v)) v <- v[[1]]
  as.character(v)[1]
}

# ---- query Crossref ---------------------------------------------------------------------------
rows <- lapply(entries, function(e) {
  first_author <- clean(sub(",.*$", "", sub(" and .*$", "", e$author)))
  q <- URLencode(paste(clean(e$title), first_author, e$year), reserved = TRUE)
  url <- paste0("https://api.crossref.org/works?rows=3&select=title,author,container-title,",
                "volume,issue,page,issued,DOI,type&query.bibliographic=", q,
                "&mailto=valofils@gmail.com")
  res <- get_json(url)
  Sys.sleep(0.6)   # be polite to the API
  it <- res$message$items
  if (is.null(it) || !length(it)) {
    return(data.frame(key = e$key, status = "no Crossref match", cr_title = NA_character_))
  }
  # pick the item whose title best matches
  titles <- vapply(it, pick, character(1), field = "title")
  score <- vapply(titles, function(t) {
    a <- norm(t); b <- norm(e$title)
    if (is.na(a)) return(0)
    n <- max(nchar(a), nchar(b))
    1 - adist(a, b)[1, 1] / n
  }, numeric(1))
  i <- which.max(score)
  item <- it[[i]]
  one <- function(x) if (is.null(x) || !length(x)) NA_character_ else as.character(x)[1]
  yr <- one(tryCatch(item$issued$`date-parts`[[1]][[1]], error = function(e) NULL))
  cr <- list(title = titles[i], journal = pick(item, "container-title"), year = yr,
             volume = pick(item, "volume"), issue = pick(item, "issue"),
             page = pick(item, "page"), doi = pick(item, "DOI"))

  same_pages <- function(a, b) {
    if (is.na(a) || is.na(b)) return(NA)
    pa <- strsplit(gsub("[^0-9S]", " ", a), " +")[[1]]
    pb <- strsplit(gsub("[^0-9S]", " ", b), " +")[[1]]
    pa <- pa[nzchar(pa)]; pb <- pb[nzchar(pb)]
    length(pa) && length(pb) && pa[1] == pb[1]
  }
  data.frame(
    key = e$key, status = if (score[i] > 0.9) "title matched" else "check title",
    title_score = round(score[i], 2),
    bib_title = clean(e$title), cr_title = cr$title,
    bib_journal = clean(e$journal), cr_journal = cr$journal,
    bib_year = e$year, cr_year = cr$year,
    bib_volume = e$volume, cr_volume = cr$volume,
    bib_issue = e$number, cr_issue = cr$issue,
    bib_pages = clean(e$pages), cr_pages = cr$page,
    doi = cr$doi,
    year_ok = identical(as.character(e$year), as.character(cr$year)),
    volume_ok = identical(as.character(e$volume), as.character(cr$volume)),
    issue_ok = identical(as.character(e$number), as.character(cr$issue)),
    first_page_ok = same_pages(clean(e$pages), cr$page),
    stringsAsFactors = FALSE)
})

out <- bind_rows(rows)
write.csv(out, file.path(paths$tables, "reference_check.csv"), row.names = FALSE)
options(width = 200)
print(out[, c("key", "status", "title_score", "year_ok", "volume_ok", "issue_ok", "first_page_ok", "doi")],
      row.names = FALSE)
message("52: wrote reference_check.csv for ", nrow(out), " entries")
