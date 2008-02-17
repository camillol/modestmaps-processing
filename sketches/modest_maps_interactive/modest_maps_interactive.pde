
// pan, zoom and rotate
float tx = 0, ty = 0;
float sc = 1;
float a = 0.0;

AbstractMapProvider provider;

void setup() {
  size(screen.width/2, screen.height/2, P3D);

  provider = new Microsoft.HybridProvider();

  tx = -128 + width/2;
  ty = -128 + height/2;
  
  PFont f = createFont("Helvetica",16);
  textFont(f,16);
  textAlign(LEFT, TOP);
}

void draw() {
  background(0);

  pushMatrix();
  translate(width/2, height/2);
  scale(sc,sc);
//  rotate(radians(a));
  translate(-width/2, -height/2);
  translate(tx,ty);

  float minX = screenX(0,0);
  float minY = screenY(0,0);
  float maxX = screenX(256,256);
  float maxY = screenY(256,256);

//  println("map: " + nf(minX,1,3) + " " + nf(minY,1,3) + " : " + nf(maxX,1,3) + " " + nf(maxY,1,3));
  
  // do the diagonal because we might rotate
  float sideLength = dist(minX, minY, maxX, maxY);
  float zoom0Length = dist(0,0,256,256); // yes I should hard-code this
//  println(zoom0Length + " --> " + sideLength);

  // 0 when sideLength == 256, 1 when sideLength == 512, 2 when sideLength == 1024
  int zoom = min(20, max(1, (int)round(log(sideLength/zoom0Length) / log(2))));

  int cols = (int)pow(2,zoom);
  int rows = (int)pow(2,zoom);
//  println("rows/cols: " + rows + "/" + cols);
//  println("tileCount: " + (rows * cols));

  int screenCols = (int)ceil(cols * dist(0,0,width,height) / sideLength);
//  println("screenCols: " + screenCols);

  // find the biggest box the screen would fit in, aligned with the map:
  float screenMinX = 0;
  float screenMinY = 0;
  float screenMaxX = width;
  float screenMaxY = height;
//  println("screen: " + nf(screenMinX,1,3) + " " + nf(screenMinY,1,3) + " : " + nf(screenMaxX,1,3) + " " + nf(screenMaxY,1,3));
  // TODO align this box!
  
  // find start and end columns
  int minCol = (int)floor(cols * (screenMinX-minX) / (maxX-minX));
  int maxCol = (int)ceil(cols * (screenMaxX-minX) / (maxX-minX));
  int minRow = (int)floor(rows * (screenMinY-minY) / (maxY-minY));
  int maxRow = (int)ceil(rows * (screenMaxY-minY) / (maxY-minY));
//  println("row/col: " + minCol + ", " + minRow + " : " + maxCol + ", " + maxRow);

  minCol -= 1;
  minRow -= 1;
  maxCol += 1;
  maxRow += 1;

  Vector visibleKeys = new Vector();

  pushMatrix();
  scale(1.0/pow(2,zoom));
  for (int col = minCol; col <= maxCol; col++) {
    for (int row = minRow; row <= maxRow; row++) {
      Coordinate coord = provider.sourceCoordinate(new Coordinate(row,col,zoom));
      coord.row = round(coord.row);
      coord.column = round(coord.column);
      coord.zoom = round(coord.zoom);
      visibleKeys.add(coord);
      if (images.containsKey(coord)) {
        PImage tile = (PImage)images.get(coord);
        image(tile,col*256,row*256,256,256);
      }
      else {
        grabTile(coord);
        fill(col >= 0 && col < cols && row >= 0 && row < rows ? 128 : 80);
        stroke(255);
        rect(col*256,row*256,256,256);
        fill(255);
        noStroke();
        textAlign(LEFT, TOP);
        text("c:"+col+" "+"r:"+row+" "+"z:"+zoom, col*256, row*256);
/*      textAlign(RIGHT, TOP);
        text("c:"+col+" "+"r:"+row, (1+col)*256, row*256);
        textAlign(LEFT, BOTTOM);
        text("c:"+col+" "+"r:"+row, col*256, (1+row)*256);
        textAlign(RIGHT, BOTTOM);
        text("c:"+col+" "+"r:"+row, (1+col)*256, (1+row)*256); */
      }    
    }
  }
  popMatrix();
  
  popMatrix();

//  println(pending.size() + " pending...");
//  println(queue.size() + " in queue, pruning...");
  queue.retainAll(visibleKeys);
//  println(queue.size() + " in queue");
//  println();

  processQueue();
  
  if (keyPressed) {
/*    if (key == CODED) {
      if (keyCode == LEFT) {
        a -= 1;
      }
      else if (keyCode == RIGHT) {
        a += 1;        
      }
    } 
    else */ if (key == '+' || key == '=') {
      sc *= 1.05;
    }
    else if (key == '_' || key == '-' && sc > 0.1) {
      sc *= 1.0/1.05;
    }
    else if (key == ' ') {
      sc = 1.0;
      tx = 0;
      ty = 0; 
      a = 0;
    }
  }

//  println();
  
}

void mouseDragged() {
  float dx = (mouseX - pmouseX) / sc;
  float dy = (mouseY - pmouseY) / sc;
  float angle = radians(-a);
  float rx = cos(angle)*dx - sin(angle)*dy;
  float ry = sin(angle)*dx + cos(angle)*dy;
  tx += rx;
  ty += ry;
}

// loading tiles
Hashtable pending = new Hashtable(); // coord.toString() -> TileLoader
// loaded tiles
Hashtable images = new Hashtable();  // coord.toString() -> PImage
// coords waiting to load
Vector queue = new Vector(); // coord

void grabTile(Coordinate coord) {
  if (!pending.containsKey(coord) && !queue.contains(coord) && !images.containsKey(coord)) {
//    println("adding " + coord.toString() + " to queue");
    queue.add(coord);
  }
}

class TileLoader implements Runnable {
  Coordinate coord;
  TileLoader(Coordinate coord) {
    this.coord = coord; 
  }
  public void run() {
    String url = provider.getTileUrls(coord)[0];
    println("loading: " + url);
    PImage img = loadImage(url); // TODO: layered tiles
//    println("loaded: " + url);
    tileDone(coord, img);
  }
}

void tileDone(Coordinate coord, PImage img) {
  images.put(coord, img);
  pending.remove(coord);  
}

void processQueue() {
  while (pending.size() < 4 && queue.size() > 0) {
    Coordinate coord = (Coordinate)queue.remove(0);
    TileLoader tileLoader = new TileLoader(coord);
    pending.put(coord, tileLoader);
    new Thread(tileLoader).start();
  }  
}
