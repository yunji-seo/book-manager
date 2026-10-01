# Private database helper. Quoted CSV supports commas, quotes and backslashes.
# Multiline fields are deliberately rejected by the public database interface.
function norm(s) { gsub(/^ +| +$/, "", s); gsub(/ +/, " ", s); return tolower(s) }
function key(t,a) { return norm(t) SUBSEP norm(a) }
function quote(s) { gsub(/"/, "\"\"", s); return "\"" s "\"" }
function csv(    i,s) { s=quote(f[1]); for(i=2;i<=7;i++) s=s "," quote(f[i]); return s }
function tsv(    i,s) { s=f[1]; for(i=2;i<=7;i++) s=s "\t" f[i]; return s }
function parse(s,    i,c,n,inside) {
    split("",f); n=1; inside=0
    for(i=1;i<=length(s);i++) {
        c=substr(s,i,1)
        if(c=="\"") {
            if(inside && substr(s,i+1,1)=="\"") { f[n]=f[n] "\""; i++ }
            else inside=!inside
        } else if(c=="," && !inside) n++
        else f[n]=f[n] c
    }
    if(inside || n!=7) { print "Invalid CSV row " NR > "/dev/stderr"; broken=1; exit 1 }
}
BEGIN {
    op=ENVIRON["DB_OP"]; target=key(ENVIRON["DB_TITLE"],ENVIRON["DB_AUTHOR"])
    mutate=(op=="add" || op ~ /^update-/)
}
NR==1 {
    sub(/\r$/, "")
    if($0!="title,author,genre,status,rating,link,year") { broken=1; print "Unexpected CSV schema" > "/dev/stderr"; exit 1 }
    if(mutate) print
    next
}
{
    sub(/\r$/, ""); parse($0)
    matched=(key(f[1],f[2])==target)
    if(matched) found=1
    if(op=="list" || (op=="search" && index(tolower(tsv()),tolower(ENVIRON["DB_QUERY"])))) print tsv()
    if(op=="update-status" && matched) f[4]=ENVIRON["DB_STATUS"]
    if(op=="update-rating" && matched) f[5]=ENVIRON["DB_RATING"]
    if(mutate) print csv()
}
END {
    if(broken) exit 1
    if(op=="exists") exit !found
    if(op ~ /^update-/ && !found) { print "Book not found" > "/dev/stderr"; exit 1 }
    if(op=="add") {
        if(found) { print "Book already exists" > "/dev/stderr"; exit 1 }
        f[1]=ENVIRON["DB_TITLE"]; f[2]=ENVIRON["DB_AUTHOR"]; f[3]=ENVIRON["DB_GENRE"]
        f[4]=ENVIRON["DB_STATUS"]; f[5]=ENVIRON["DB_RATING"]; f[6]=ENVIRON["DB_LINK"]; f[7]=ENVIRON["DB_YEAR"]
        print csv()
    }
}
