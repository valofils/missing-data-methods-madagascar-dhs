# 51_manuscript_latex.R — build the LaTeX manuscript and compile it to PDF
#
# Usage: Rscript R/51_manuscript_latex.R        (run R/50_assemble_manuscript.R first)
#
# Reads the assembled Markdown manuscript, converts numeric citations to \cite keys, converts the
# body to LaTeX with pandoc, and wraps it in a preamble. Tables are the LaTeX fragments written by
# 40_tables.R; figures are the PDFs written by 41_figures.R with captions from figure_captions.csv,
# so every number and caption still has a single source. References are emitted as a numbered
# thebibliography in citation order (the entries are reproduced verbatim from the section drafts,
# not re-parsed into BibTeX). Compiles with latexmk if a LaTeX distribution is available.
#
# Output: docs/manuscript/manuscript.tex and manuscript.pdf

source(here::here("R", "00_setup.R"))

man_dir <- here("docs", "manuscript")
md_file  <- file.path(man_dir, "manuscript_draft.md")
stopifnot(file.exists(md_file))

TITLE <- paste("Missing-data methods and equity estimates of child undernutrition:",
               "a methodological study using the 2021 Madagascar Demographic and Health Survey")

# Sole author of the manuscript. AFFILIATION may be empty (no institutional affiliation);
# the author block then carries the name and contact email only.
AUTHOR      <- "Mariel Andrianavalondrahona"
AFFILIATION <- ""
EMAIL       <- "valofils@gmail.com"

# Tables and figures, in the order they should appear at the end of the manuscript
TABLES <- c("table1_sample_missingness", "table2_prevalence_by_method", "table3_simulation",
            "tableS2_prevalence_sensitivity", "tableS3_simulation_full",
            "tableS4_simulation_ranking", "tableS5_ntree_substudy")
FIGURES <- c("figure1_equity_ranking", "figure2_simulation_coverage",
             "figureS1_equity_ranking_sensitivity", "figureS2_simulation_bias")

md <- readLines(md_file, warn = FALSE, encoding = "UTF-8")

# ---- split body / references ------------------------------------------------------------------
ref_head <- grep("^## References", md)[1]
stopifnot(!is.na(ref_head))
refs <- md[(ref_head + 1):length(md)]
refs <- refs[nzchar(trimws(refs))]
body <- md[seq_len(ref_head - 1)]
body <- body[!startsWith(body, ">")]          # drop the assembly note
body <- body[!grepl("^# ", body)]             # title is set in the preamble

ref_num <- as.integer(sub("^([0-9]+)[.].*$", "\\1", refs))
ref_txt <- sub("^[0-9]+[.] ", "", refs)
stopifnot(!anyNA(ref_num), identical(ref_num, seq_along(ref_num)))

# ---- map reference numbers to BibTeX keys --------------------------------------------------------
# Each .bib entry stores the drafted reference string in `origtext`; matching on a normalised form
# of that string ties the numbered list to the keys, and fails loudly if the two drift apart.
bib_file <- file.path(man_dir, "references.bib")
stopifnot(file.exists(bib_file))
bib <- readLines(bib_file, warn = FALSE, encoding = "UTF-8")
bib_keys <- sub("^@[A-Za-z]+\\{([^,]+),.*$", "\\1", grep("^@", bib, value = TRUE))
orig_idx <- grep("^\\s*origtext = \\{", bib)
bib_orig <- sub("^\\s*origtext = \\{(.*)\\},?\\s*$", "\\1", bib[orig_idx])
stopifnot(length(bib_keys) == length(bib_orig), !anyDuplicated(bib_keys))

normalise <- function(x) {
  x <- tolower(x)
  x <- gsub("[‐-―−]", "-", x)          # dashes of all kinds
  x <- iconv(x, "UTF-8", "ASCII//TRANSLIT")           # accents
  x <- gsub("[^a-z0-9]", "", x)
  x
}
key_for <- setNames(bib_keys, normalise(bib_orig))
ref_keys <- key_for[normalise(ref_txt)]
if (anyNA(ref_keys)) {
  stop("no .bib entry matches these references (check origtext fields):\n  ",
       paste(ref_txt[is.na(ref_keys)], collapse = "\n  "))
}
unused_keys <- setdiff(bib_keys, ref_keys)
if (length(unused_keys)) message("51: .bib entries not cited: ", paste(unused_keys, collapse = ", "))

cite_pat <- "\\[[0-9]+(,[0-9]+)*\\]"
body <- vapply(body, function(line) {
  toks <- regmatches(line, gregexpr(cite_pat, line))[[1]]
  if (!length(toks)) return(line)
  new <- vapply(toks, function(tok) {
    nums <- as.integer(strsplit(gsub("[][]", "", tok), ",")[[1]])
    paste0("\\cite{", paste(ref_keys[nums], collapse = ","), "}")
  }, character(1))
  regmatches(line, gregexpr(cite_pat, line)) <- list(new)
  line
}, character(1), USE.NAMES = FALSE)

# Markdown "Table 1." / "Figure 2." mentions stay as plain text: the floats carry their own numbers
tmp_md <- tempfile(fileext = ".md")
writeLines(body, tmp_md, useBytes = TRUE)

if (!rmarkdown::pandoc_available()) {
  rs <- "C:/Program Files/RStudio/resources/app/bin/quarto/bin/tools"
  if (dir.exists(rs)) Sys.setenv(RSTUDIO_PANDOC = rs)
}
stopifnot(rmarkdown::pandoc_available())
tmp_tex <- tempfile(fileext = ".tex")
rmarkdown::pandoc_convert(input = normalizePath(tmp_md), from = "markdown+smart+raw_tex",
                          to = "latex", output = normalizePath(tmp_tex, mustWork = FALSE),
                          options = "--shift-heading-level-by=-1")  # "##" -> \section
tex_body <- readLines(tmp_tex, warn = FALSE, encoding = "UTF-8")

# pandoc wraps caption-less tables in "{\def\LTcaptype{none} ... }", which the caption package
# rejects ("No counter 'none' defined"). The wrapper only suppresses a caption these tables do not
# have, so drop it and its closing brace.
lt <- grep("\\def\\LTcaptype", tex_body, fixed = TRUE)
for (i in rev(lt)) {
  close_i <- which(trimws(tex_body) == "}" & seq_along(tex_body) > i)
  end_i <- which(trimws(tex_body) == "\\end{longtable}" & seq_along(tex_body) > i)
  stopifnot(length(end_i) > 0, length(close_i) > 0, close_i[1] == end_i[1] + 1)
  tex_body <- tex_body[-c(i, close_i[1])]
}

# ---- tables and figures -------------------------------------------------------------------------
caps <- read.csv(file.path(paths$figures, "figure_captions.csv"), stringsAsFactors = FALSE)
esc <- function(x) gsub("%", "\\\\%", x)

# pdfLaTeX (Latin Modern) has no glyphs for the few Unicode symbols used in the text, tables and
# captions; map them to LaTeX equivalents so the build works with any engine.
UNI <- c("ρ" = "$\\rho$", "τ" = "$\\tau$", "≥" = "$\\ge$", "≤" = "$\\le$",
         "±" = "$\\pm$", "−" = "$-$", "×" = "$\\times$", "†" = "$\\dagger$",
         "≈" = "$\\approx$", "’" = "'", "‘" = "`", " " = " ",
         "⁰" = "$^0$", "¹" = "$^1$", "²" = "$^2$", "³" = "$^3$",
         "⁴" = "$^4$", "⁵" = "$^5$", "⁶" = "$^6$", "⁷" = "$^7$",
         "⁸" = "$^8$", "⁹" = "$^9$")
fix_unicode <- function(x) {
  for (ch in names(UNI)) x <- gsub(ch, UNI[[ch]], x, fixed = TRUE)
  x
}

# tables too wide for A4 portrait are rotated
WIDE <- c("table2_prevalence_by_method", "tableS2_prevalence_sensitivity",
          "tableS3_simulation_full")
table_block <- unlist(lapply(TABLES, function(t) {
  f <- file.path(paths$tables, paste0(t, ".tex"))
  if (!file.exists(f)) return(character(0))
  tex <- readLines(f, warn = FALSE, encoding = "UTF-8")
  if (t %in% WIDE) tex <- c("\\begin{landscape}", tex, "\\end{landscape}")
  c(paste0("% --- ", t), tex, "\\clearpage", "")
}))

figure_block <- unlist(lapply(FIGURES, function(f) {
  pdf <- file.path(paths$figures, paste0(f, ".pdf"))
  if (!file.exists(pdf)) return(character(0))
  cap <- caps[caps$figure == f, ]
  lab <- if (nrow(cap)) paste0("\\textbf{", esc(cap$title[1]), ".} ", esc(cap$caption[1])) else f
  c("\\begin{figure}[p]", "\\centering",
    paste0("\\includegraphics[width=\\linewidth,height=0.86\\textheight,keepaspectratio]{",
           gsub("\\\\", "/", pdf), "}"),
    paste0("\\caption{", lab, "}"),
    "\\end{figure}", "\\clearpage", "")
}))

# BibTeX bibliography (vancouver.bst = NLM style, numbered in citation order)
bib_block <- c("\\bibliographystyle{vancouver}", "\\bibliography{references}")

preamble <- c(
  "% Generated by R/51_manuscript_latex.R from the section drafts in docs/manuscript/.",
  "% Edit the section drafts, then re-run R/50_assemble_manuscript.R and this script.",
  "\\documentclass[11pt,a4paper]{article}",
  "\\usepackage[utf8]{inputenc}", "\\usepackage[T1]{fontenc}", "\\usepackage{lmodern}",
  "\\usepackage[margin=2.5cm]{geometry}", "\\usepackage{microtype}",
  "\\usepackage{booktabs}", "\\usepackage{longtable}", "\\usepackage{array}",
  "\\usepackage{calc}",   # pandoc table column widths use calc syntax
  "\\usepackage{pdflscape}",   # landscape pages for wide tables
  "\\usepackage{caption}", "\\usepackage{graphicx}", "\\usepackage{float}",
  "\\usepackage{amsmath}", "\\usepackage{textcomp}", "\\usepackage{lineno}",
  "\\usepackage[hidelinks]{hyperref}",
  "\\captionsetup{font=small,labelfont=bf,justification=raggedright,singlelinecheck=false}",
  # pandoc emits \tightlist for compact lists; its default template defines it, ours must too
  "\\providecommand{\\tightlist}{\\setlength{\\itemsep}{0pt}\\setlength{\\parskip}{0pt}}",
  "\\setlength{\\parskip}{0.5em}", "\\setlength{\\parindent}{0pt}",
  "\\linespread{1.25}",
  paste0("\\title{", TITLE, "}"),
  paste0("\\author{", AUTHOR,
         if (nzchar(AFFILIATION)) paste0("\\\\[2pt]\\small ", AFFILIATION) else "",
         "\\\\[2pt]\\small\\texttt{", EMAIL, "}}"),
  "\\date{Draft compiled \\today}",
  "\\begin{document}",
  "\\linenumbers",
  "\\maketitle")

doc <- c(preamble, "", fix_unicode(tex_body), "", "\\clearpage", fix_unicode(bib_block), "",
         "\\clearpage", "\\section*{Tables}", "", fix_unicode(table_block),
         "\\section*{Figures}", "", fix_unicode(figure_block), "\\end{document}")
writeLines(doc, file.path(man_dir, "manuscript.tex"), useBytes = TRUE)
message("51: wrote manuscript.tex (", length(ref_num), " references, ",
        length(TABLES), " tables, ", length(FIGURES), " figures)")

# ---- compile -------------------------------------------------------------------------------------
latexmk <- Sys.which("latexmk")
if (nzchar(latexmk)) {
  owd <- setwd(man_dir); on.exit(setwd(owd), add = TRUE)
  code <- system2(latexmk, c("-pdf", "-interaction=nonstopmode", "-halt-on-error",
                             "manuscript.tex"), stdout = "latexmk.log", stderr = "latexmk.log")
  if (code == 0 && file.exists("manuscript.pdf")) {
    message("51: compiled manuscript.pdf")
  } else {
    message("51: latexmk failed (exit ", code, ") - see docs/manuscript/latexmk.log")
  }
} else {
  message("51: latexmk not found; manuscript.tex written but not compiled")
}
