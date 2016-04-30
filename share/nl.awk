BEGIN {
    i = 1
}
{
    print i d $0
    i++
}
