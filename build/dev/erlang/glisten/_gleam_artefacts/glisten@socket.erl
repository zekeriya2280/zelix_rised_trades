-module(glisten@socket).
-compile([no_auto_import, nowarn_ignored, nowarn_unused_vars, nowarn_unused_function, nowarn_nomatch, inline]).
-export([reason_to_string/1]).
-export_type([socket_reason/0, listen_socket/0, socket/0]).

-type socket_reason() :: closed | timeout | badarg | terminated | eaddrinuse | eaddrnotavail | eafnosupport | ealready | econnaborted | econnrefused | econnreset | edestaddrreq | ehostdown | ehostunreach | einprogress | eisconn | emsgsize | enetdown | enetunreach | enopkg | enoprotoopt | enotconn | enotty | enotsock | eproto | eprotonosupport | eprototype | esocktnosupport | etimedout | ewouldblock | exbadport | exbadseq | eacces | eagain | ebadf | ebadmsg | ebusy | edeadlk | edeadlock | edquot | eexist | efault | efbig | eftype | eintr | einval | eio | eisdir | eloop | emfile | emlink | emultihop | enametoolong | enfile | enobufs | enodev | enolck | enolink | enoent | enomem | enospc | enosr | enostr | enosys | enotblk | enotdir | enotsup | enxio | eopnotsupp | eoverflow | eperm | epipe | erange | erofs | espipe | esrch | estale | etxtbsy | exdev.

-type listen_socket() :: any().

-type socket() :: any().

-file("src\\glisten\\socket.gleam", 87).
-spec reason_to_string(socket_reason()) -> binary().
reason_to_string(Reason) ->
    case Reason of
        closed ->
            ~"Closed";

        timeout ->
            ~"Timeout";

        badarg ->
            ~"Badarg";

        terminated ->
            ~"Terminated";

        eaddrinuse ->
            ~"Eaddrinuse";

        eaddrnotavail ->
            ~"Eaddrnotavail";

        eafnosupport ->
            ~"Eafnosupport";

        ealready ->
            ~"Ealready";

        econnaborted ->
            ~"Econnaborted";

        econnrefused ->
            ~"Econnrefused";

        econnreset ->
            ~"Econnreset";

        edestaddrreq ->
            ~"Edestaddrreq";

        ehostdown ->
            ~"Ehostdown";

        ehostunreach ->
            ~"Ehostunreach";

        einprogress ->
            ~"Einprogress";

        eisconn ->
            ~"Eisconn";

        emsgsize ->
            ~"Emsgsize";

        enetdown ->
            ~"Enetdown";

        enetunreach ->
            ~"Enetunreach";

        enopkg ->
            ~"Enopkg";

        enoprotoopt ->
            ~"Enoprotoopt";

        enotconn ->
            ~"Enotconn";

        enotty ->
            ~"Enotty";

        enotsock ->
            ~"Enotsock";

        eproto ->
            ~"Eproto";

        eprotonosupport ->
            ~"Eprotonosupport";

        eprototype ->
            ~"Eprototype";

        esocktnosupport ->
            ~"Esocktnosupport";

        etimedout ->
            ~"Etimedout";

        ewouldblock ->
            ~"Ewouldblock";

        exbadport ->
            ~"Exbadport";

        exbadseq ->
            ~"Exbadseq";

        eacces ->
            ~"Eacces";

        eagain ->
            ~"Eagain";

        ebadf ->
            ~"Ebadf";

        ebadmsg ->
            ~"Ebadmsg";

        ebusy ->
            ~"Ebusy";

        edeadlk ->
            ~"Edeadlk";

        edeadlock ->
            ~"Edeadlock";

        edquot ->
            ~"Edquot";

        eexist ->
            ~"Eexist";

        efault ->
            ~"Efault";

        efbig ->
            ~"Efbig";

        eftype ->
            ~"Eftype";

        eintr ->
            ~"Eintr";

        einval ->
            ~"Einval";

        eio ->
            ~"Eio";

        eisdir ->
            ~"Eisdir";

        eloop ->
            ~"Eloop";

        emfile ->
            ~"Emfile";

        emlink ->
            ~"Emlink";

        emultihop ->
            ~"Emultihop";

        enametoolong ->
            ~"Enametoolong";

        enfile ->
            ~"Enfile";

        enobufs ->
            ~"Enobufs";

        enodev ->
            ~"Enodev";

        enolck ->
            ~"Enolck";

        enolink ->
            ~"Enolink";

        enoent ->
            ~"Enoent";

        enomem ->
            ~"Enomem";

        enospc ->
            ~"Enospc";

        enosr ->
            ~"Enosr";

        enostr ->
            ~"Enostr";

        enosys ->
            ~"Enosys";

        enotblk ->
            ~"Enotblk";

        enotdir ->
            ~"Enotdir";

        enotsup ->
            ~"Enotsup";

        enxio ->
            ~"Enxio";

        eopnotsupp ->
            ~"Eopnotsupp";

        eoverflow ->
            ~"Eoverflow";

        eperm ->
            ~"Eperm";

        epipe ->
            ~"Epipe";

        erange ->
            ~"Erange";

        erofs ->
            ~"Erofs";

        espipe ->
            ~"Espipe";

        esrch ->
            ~"Esrch";

        estale ->
            ~"Estale";

        etxtbsy ->
            ~"Etxtbsy";

        exdev ->
            ~"Exdev"
    end.

