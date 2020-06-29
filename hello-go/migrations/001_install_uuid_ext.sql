-- Creates the extension for uuid generation, if this fails the ext has to be installed

create extension if not exists "uuid-ossp";

---- create above / drop below ----

drop extension if not exists "uuid-ossp";
