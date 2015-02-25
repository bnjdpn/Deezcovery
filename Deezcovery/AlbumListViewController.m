//
//  AlbumListViewController.m
//  Deezcovery
//

#import "ArtistService.h"
#import "DBManager.h"
#import "AlbumListViewController.h"
#import "AlbumService.h"
#import "Album.h"
#import "Artist.h"
#import "TrackListViewController.h"
#import "FavArtistDpo.h"
#import "FavAlbumDpo.h"
#import "FavTrackDpo.h"
#import "TrackService.h"

#define CELL_ID @"ALBUM_CELL_ID"
#define SEGUE_ID @"ALBUM_SEGUE_ID"

@interface AlbumListViewController ()

@property (strong, nonatomic) AlbumService *albumService;
@property (strong, nonatomic) Album *selectedAlbum;
@property (strong, nonatomic) NSMutableArray *artistAlbums;
@property (weak, nonatomic) IBOutlet UITableView *albums;
@property (weak, nonatomic) IBOutlet UINavigationBar *titleNavigationBar;

@end

@implementation AlbumListViewController

- (void)setupModel{
    self.albumService = [AlbumService sharedInstance];
}

- (void)configureOutlets{
    self.albums.delegate = self;
    self.albums.dataSource = self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    [self setupModel];
    [self configureOutlets];
    
    [self setTitle:self.artist.name];
    
    //how you get albums? via web or coredata
    self.artistAlbums = [self.albumService getAlbumsByArtist:self.artist];
    [self.albums reloadData];
    
    if ([self.artistAlbums count] == 0) {
        [self loadFavAlbums];
    }
    else{
        [self loadAlbums];
    }
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

- (void)viewWillAppear:(BOOL)animated{
    [super viewWillAppear:animated];
    [self.albums reloadData];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [self.artistAlbums count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    UITableViewCell *cell = [self.albums dequeueReusableCellWithIdentifier:CELL_ID];
    
    // load cell artist
    
    Album *album = self.artistAlbums[indexPath.row];
    UIImage *image= album.UIcover;
    
    //if image is already saved
    if(image){
        cell.textLabel.text = album.title;
        cell.imageView.image = image;
    }else{
        //else it will be downloaded
        dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0ul);
        dispatch_async(queue, ^{
            
            //downloaded image
            NSData *data = [[NSData alloc] initWithContentsOfURL:[NSURL URLWithString:album.cover]];
            album.UIcover = [UIImage imageWithData:data];
            
            //put image in cells in an asynchronous way
            dispatch_async(dispatch_get_main_queue(), ^{
                cell.textLabel.text = album.title;
                cell.imageView.image = album.UIcover ;
            });
        });
    }
    
    
    return cell;
}

- (void) loadAlbums {
    
    @try {
        
        self.artistAlbums = [self.albumService getAlbumsByArtist:self.artist];
        
        [self.albums reloadData];
        
        if ([self.artistAlbums count] == 0) {
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"No album"
                                                            message:@"There is no album for this artist."
                                                           delegate:self
                                                  cancelButtonTitle:@"OK"
                                                  otherButtonTitles:nil];
            [alert show];
        }
        
        
    }
    
    @catch(NSException *exception) {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Sorry"
                                                        message:@"Can not find the albums."
                                                       delegate:self
                                              cancelButtonTitle:@"OK"
                                              otherButtonTitles:nil];
        [alert show];
    }
    
}

-(void) loadFavAlbums {
    @try {
        
        DBManager *db = [DBManager sharedInstance];
        
        //tool conversion NSString to NSnumber
        NSNumberFormatter *f = [[NSNumberFormatter alloc] init];
        f.numberStyle = NSNumberFormatterDecimalStyle;
        
        // Récupérer les favoris
        NSArray * favAlbum = [db getAlbumsByArtist:[f numberFromString:self.artist._id]];
        
        if ([favAlbum count] == 0) {
            // Si aucun favoris
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"No favorite"
                                                            message:@"You do not have any favorites"
                                                           delegate:self
                                                  cancelButtonTitle:@"OK"
                                                  otherButtonTitles:nil];
            
            [alert show];
        } else {
            // Sinon, convertion ArtistDpo -> Artist
            self.artistAlbums = [[NSMutableArray alloc]init];
            
            self.artistAlbums = [self.albumService getAlbumsByFavAlbumsArray:favAlbum];

            [self.albums reloadData];
            
        }
        
    }
    
    @catch(NSException *exception) {
        
        //Gestion des exceptions
        
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Sorry"
                                                        message:@"Impossible to load favorites."
                                                       delegate:self
                                              cancelButtonTitle:@"OK"
                                              otherButtonTitles:nil];
        [alert show];
    }
}

- (IBAction)didTouchOnAddToFavButton:(id)sender {
    
    @try {
        
        NSNumber *artistId = [NSNumber numberWithInteger:[self.artist._id integerValue]];
        
        DBManager * db = [DBManager sharedInstance];
        
        // Si l'artiste n'est pas déjà en fav
        if ([db getFavArtistById:artistId] == nil) {
            
            // Création du FavArtistDpo
            FavArtistDpo * favArtist = [db createManagedObjectWithName:NSStringFromClass([FavArtistDpo class])];
            favArtist.id = artistId;
            favArtist.name = self.artist.name;
            favArtist.picture = [NSData dataWithContentsOfURL:[NSURL URLWithString:self.artist.picture]];
            
            // TODO
            // Pour chaque album de l'artiste
                        for (Album *album in self.artistAlbums) {
                            // Création du FavAlbumDpo
                            FavAlbumDpo * favAlbum = [db createManagedObjectWithName:NSStringFromClass([FavAlbumDpo class])];
                            favAlbum.id = [NSNumber numberWithInteger:[album._id integerValue]];
                            favAlbum.title = album.title;
                            favAlbum.cover = [NSData dataWithContentsOfURL:[NSURL URLWithString:album.cover]];
                            favAlbum.artist = favArtist;
                        }
            
            //Commit
            [db persistData];
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Favorite"
                                                            message:@"Artist added to favorites."
                                                           delegate:self
                                                  cancelButtonTitle:@"OK"
                                                  otherButtonTitles:nil];
            [alert show];
        } else {
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Favorite"
                                                            message:@"This artist is already in your favorites. Do you want to want to delete it ?"
                                                           delegate:self
                                                  cancelButtonTitle:@"Cancel"
                                                  otherButtonTitles:@"Delete", nil];
            [alert show];
        }
        
    }
    
    @catch(NSException *exception) {
        
        //Gestion des exceptions
        
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Sorry"
                                                        message:@"Impossible to add to favorites."
                                                       delegate:self
                                              cancelButtonTitle:@"OK"
                                              otherButtonTitles:nil];
        [alert show];
    }
    
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    
    // Méthode appelée quand on clique sur le bouton d'une UIAlertView
    
    if ([[alertView buttonTitleAtIndex:buttonIndex] isEqualToString:@"Delete"]) {
        DBManager * db = [DBManager sharedInstance];
        FavArtistDpo * favArtist = [db getFavArtistById:[NSNumber numberWithInteger:[self.artist._id integerValue]]];
        [db deleteManagedObject:favArtist];
        [db persistData];
        
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Favorite"
                                                        message:@"Artist removed from favorites"
                                                       delegate:self
                                              cancelButtonTitle:@"OK"
                                              otherButtonTitles:nil];
        [alert show];
        
        UINavigationController *navController = self.navigationController;
        [navController popViewControllerAnimated:YES];
    }
    
}

#pragma mark - Navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([segue.identifier isEqualToString:SEGUE_ID]){
        TrackListViewController *controller = segue.destinationViewController;
        controller.album = self.selectedAlbum;
    }
}

#pragma mark - UITableView Delegate
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath{
    self.selectedAlbum = self.artistAlbums[indexPath.row];
    [self performSegueWithIdentifier:SEGUE_ID sender:self];
}

@end
