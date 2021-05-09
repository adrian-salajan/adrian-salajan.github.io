---
layout: post
title:  "Image editing with Comonads"
date:   2021-09-10 08:30:00 -0200
image:
    path: assets/posts/comonad-image/average-16px.png
tags: [functional programming, scala, category-theory, comonad]


---
Continuing from [image editing with Monads](/blog/2021/04/09/image-editing-with-monads), we will now understand comonads by editing images with it.

### Comonad

A comonad is like a monad only in reverse. Monads wraps contexts over a value, comonads extract the value from the context.

A comonad is composed of 2 things:
1. A function which can extract `A` from the context `F`:  `extract(a: F[A]): A` 
2. One of the two sets of functions which are equivalent to each other (can rewrite one in term of the other)
* `coflatMap(fa: F[A], f: F[A] => B): F[B]`
* map + `coflatten(fa: F[A]): F[F[A]]`

Below `coflatMap` is used with the enhanced syntax:

{% highlight scala %}
fa.coflatMap(f: F[A] => B): F[B]
//where fa is of type F[A]
{% endhighlight %}

These laws need to obey the following laws.

- left-identity
{% highlight scala %}
 fa.coflatMap(F.extract) == fa
{% endhighlight %}
  
- right-identity
{% highlight scala %}
  F.extract(F.coflatMap(fa)(f)) == f(fa)
{% endhighlight %}
  
- associativity
{% highlight scala %}
fa.coflatMap(f).coflatMap(g) == fa.coflatMap(x => g(x.coflatMap(f)))
{% endhighlight %}
  
They can be checked automatically with cats-laws:
  
{% highlight scala %}
checkAll("CoMonad laws", ComonadTests(Image.imComonad).comonad[Int, Int, String])
{% endhighlight scala %}

#### coflatMap
{% highlight scala %}
coflatMap(fa: F[A], f: F[A] => B): F[B]
{% endhighlight %}

We can better understand by comparing it to its dual flatmap `flatMap(fa: F[A], f: A => F[B]): F[B]`  
CoflatMap reduces the whole F[A] into a new B while maintaining the context F, while flatMap is building a completely new F[B]
from an A. Both functions perform effect chaining but while doing so coflatMap looks at the whole and flatMap looks just inside.  

#### coflatten
{% highlight scala %}
coflatten(fa: F[A]): F[F[A]]
{% endhighlight %}

This is adding effects, in duality of monad's flatten which merges them.

#### CoflatMap vs coflatten and Map

These are equivalent, we can rewrite one in terms of the other.  
This means we can choose to implement comonads through map and coflatten.

{% highlight scala %}
def coflatMap[F[_], A, B](fa: F[A])(f: F[A] => B): F[B] = map(coflatten(fa))(f)

def coflatten[F[_], A](fa: F[A]): F[F[A]] = coflatMap(fa)(fa => fa)
{% endhighlight %}


#### Comonad on Images

{% highlight scala %}
   implicit val imComonad: Comonad[Image] = new Comonad[Image] {

     override def extract[A](x: Image[A]): A = x.im(Loc(0, 0))

     override def coflatMap[A, B](fa: Image[A])(f: Image[A] => B): Image[B] = {
       new Image[B](lb =>
         f(
           new Image[A](la =>
             fa.im(Loc(lb.x + la.x, lb.y + la.y)) //lb = left identity, la = right identity
           )
         )
       )
     }

     override def map[A, B](fa: Image[A])(f: A => B): Image[B] = {
       coflatMap(fa)(img => f(extract(img)))
     }
{% endhighlight %}

For extract there is only one thing we can do, extract the first pixel, the color at coordinates (0, 0).
We can be sure that we have at least this pixel in the image, if we would
to extract (5, 5) for example it could be missing since we can have a 4/4px image size.  

Same for coflatMap, there is not much we can do that makes sense. We have an Image[A], and a function that extracts a B, but we need to return an image.
So what we do for each pixel in the original image, we construct a new image which is translated on the X and Y axis equal to the original pixels location -
or in other words an image of images where each smaller imagehaving the original pixel moved at (0, 0). We then feed this image to f and get back the new color for the pixels in Image[B].

Effectively this allows changing each pixel from the original image into a new pixel based on his neighbouring pixels.
This allows some pretty neat image manipulation capabilities.

Translate the image on X and Y axis.
{% highlight scala %}
    def translate(a: Image[Color], x: Int, y: Int): Image[Color] =
      a.coflatMap(img =>
        img.im(Loc(x, y))
      )
{% endhighlight %}

Blur - averages out a pixel based on his neighours
{% highlight scala %}
 def average(a: Image[Color], squareSizeInPixels: Int): Image[Color] =
      a.coflatMap(img => Image.regionAverage(img, squareSizeInPixels, squareSizeInPixels))

  def regionAverage(i: Image[Color], width: Int, height: Int): Color = {
    val samples = for {
      x <- rangeCenter0(width)
      y <- rangeCenter0(height)
    } yield (x, y)
    val pixels = samples
      .map(loc => i.im(Loc(loc._1, loc._2)))

    colorAverage(pixels)
  }
{% endhighlight %}

Implement image convolution transformations (multiplying pixels with a matrix giving us different effects)
{% highlight scala %}
    def convolution(a: Image[Color], kernel: DenseMatrix[Double]): Color = {
      val sumKernel = kernel.toArray.sum
      val F = if (sumKernel == 0) 1 else sumKernel

      val convolutedChannels = Image.matrix(a, kernel.cols, kernel.rows) !* kernel

      val red = convolutedChannels.red.toArray.sum / F
      val green = convolutedChannels.green.toArray.sum / F
      val blue = convolutedChannels.blue.toArray.sum / F
       Color(
       red,
         green,
         blue
      )
    }

    def gausianBlur(a: Image[Color]) =
        a.coflatMap(img => convolution(img, Image.gausianBlur))

     def edgeDetect(a: Image[Color]) =
        Image.imComonad.map(a)(_.toGray).coflatMap(img => convolution(img, Image.edgeDetect))

     def emboss(a: Image[Color]) =
         a.coflatMap(img => convolutionThreshhold(img, Image.emboss))
{% endhighlight %}

Where Image.gausianBlur, Image.edgeDetect, Image.emboss, are some matrices like below

{% highlight scala %}
  val emboss= new DenseMatrix[Double](
    rows = 3,
    cols = 3,
    Array[Double](
      -2, -1, 0,
      -1, 1, 1,
      0, 1, 2)
  )
{% endhighlight %}

#### Blur by averaging
![average](/assets/posts/comonad-image/average-16px.png)

#### Brightest pixel in a 20/20 region
![brightest](/assets/posts/comonad-image/brightest-20x20.png)

#### Edge detect
![edge_detect](/assets/posts/comonad-image/edge_detect.png)

#### Emboss
![emboss](/assets/posts/comonad-image/emboss.png)

#### Sharpen
![sharpen](/assets/posts/comonad-image/enhance_contrast.png)

#### Gausian blur
![gausian_blur](/assets/posts/comonad-image/gausian_blur.png)