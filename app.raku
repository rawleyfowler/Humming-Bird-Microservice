use Humming-Bird::Core;
use DBIish;

my $db = DBIish.connect('SQLite', :database<user-db.sqlite3>);

$db.execute(q:to/SQL/);
CREATE TABLE IF NOT EXISTS user (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name VARCHAR(20),
    age INTEGER,
    email VARCHAR
)
SQL

get('/', -> $request, $response {
    $response.html('<h1>Hello World!</h1>')
});

sub auth-middleware($request, $response, &next) {
    without $request.header('X-AUTH') {
        return $response.status(401).write('unauthorized') 
    }
    
    my $request-header = $request.header('X-AUTH');

    if $request-header ne 'foobar' {
        return $response.status(401).write('unauthorized');
    }

    &next();
}

get('/users', -> $request, $response {
    my @user-rows = $db.execute('SELECT * FROM user').allrows(:array-of-hash);
    my $json = to-json(@user-rows);
    $response.json($json);
});

sub validate-user(%user) {
    # I'll leave this up to you :^)
    %user<age> > 18;
}

post('/users', -> $request, $response {
    my %user = $request.content;
    if validate-user(%user) {
        $db.execute('INSERT INTO user (name, age, email) VALUES (?, ?, ?)', %user<name>, %user<age>, %user<email>);
        $response.status(201).json(to-json(%user));
    } else {
        $response.status(400).write('Bad Request :(');
    }
}, [ &auth-middleware ]);

get('/users/:id', -> $request, $response {
    my $id = $request.param('id');
    my @users = $db.execute('SELECT * FROM user WHERE id = ?', $id).allrows(:array-of-hash);

    return $response.status(404).html("User with id $id not found.") unless @users.elems == 1;

    $response.json(to-json(@users[0]));
});

delete('/users/:id', -> $request, $response {
    my $id = $request.param('id');

    try {
        CATCH { default { return $response.status(404).html("User with id $id not found.") } }
        $db.execute('DELETE FROM user WHERE id = ?', $id);
        $response.status(204);
    }
}, [ &auth-middleware ]);

listen(8080);
