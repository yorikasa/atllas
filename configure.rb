def open_env(path)
    open(path).each_line do |line|
        next if line[0] == '#'
        next if line =~ /^\s+?$/
        s = line.strip.split("=")
        if s[1][0] =~ /["']/ and s[1][-1] =~ /["']/
            s[1][0] = ''
            s[1][-1] = ''
        end
        ENV[s[0]] = s[1]
    end
end

open_env(".env")
