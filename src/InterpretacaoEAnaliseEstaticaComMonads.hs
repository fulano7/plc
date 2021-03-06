module InterpretacaoEAnaliseEstaticaComMonads where

-- Usando monads para representar a noção de estado no interpretador da aula
-- anterior.

-- Mesma linguagem, a entrada do interpretador.

type Id = String
type Numero = Double
data Termo = Var Id
           | Lit Numero
           | Som Termo Termo
           | Lam Id Termo
           | Apl Termo Termo
           | Atr Id Termo
           | Seq Termo Termo


-- Os valores resultantes da interpretação, a saída do interpretador,
-- agora usam o monad StateTransformer. Com isso, a manipulação do
-- estado pode passar a ser implícita.

data Valor = Num Double
           | Fun (Valor -> StateTransformer Valor) 
           | Erro


-- Estrutura similar à estrutura de IO.

data StateTransformer a = ST (Estado -> (a,Estado))

instance Monad (StateTransformer) where
   return r = ST (\e -> (r,e))
   (ST m) >>= f = ST (\e -> let (v,e1) = m e
                                (ST n) = f v
                            in (n e1)
                     ) 

type Estado = [(Id,Valor)]

type Ambiente = [(Id,Valor)]


--int :: [(Id, Valor)] -> Termo -> StateTransformer Valor

int a (Var i) = ST (\e -> (search i (a++e),e))

int a (Lit n) = return (Num n)

int a (Som t u) = do t1 <- int a t
                     u1 <- int a u
                     return (somaVal t1 u1)

int a (Lam i t) = return (Fun (\v -> int ((i,v):a) t))

int a (Apl f t) = do f1 <- int a f
                     t1 <- int a t
                     app f1 t1

int a (Atr i t) = do v <- int a t
                     assign (i,v)

		 {- = ST (\e -> let (ST f) = int a t 
                                (v,ei) = f e
                            in (v,wr (i,v) ei))  
                  -}
		     
int a (Seq t u) = do int a t
                     int a u


assign (i,v) = ST (\e -> (v,wr (i,v) e))

search i [] = Erro
search i ((j,v):l) = if i == j then v else search i l  

somaVal (Num x) (Num y) = Num (x+y)
somaVal _ _ = Erro

app (Fun f) v = f v
app _ _ = return Erro

wr (i,v) [] = [(i,v)]
wr (i,v) ((j,u):l) = if (i == j) then (j,v):l else [(j,u)] ++ (wr (i,v) l)


termo1 = (Apl (Lam "x" (Som (Var "x") (Lit 2))) (Lit 3))
termo2 = (Apl (Lam "x" (Som (Var "x") (Var "y"))) (Lit 3))
termo3 = (Seq (Atr "y" termo2) termo2)
sq1 = (Seq (Atr "y" (Lit 3)) termo2)
sq2 = (Seq (Atr "y" (Lit 3)) termo3)
sq3 = (Seq (Atr "y" (Som (Atr "z" (Lit 5)) (Var "z"))) termo3)
at t = let (ST m) = (int [] t)
       in m []

instance Show Valor where
   show (Num x) = show x
   show Erro = "Erro"
   show (Fun f) = "Função"



-- Outro exemplo de monad, dessa vez para facilitar tratamento de erro
-- Evitar coisas do tipo
--
-- if (f a /= Erro) then …(desempacota(f a))… else Erro)
--
-- Como esse teste e a operação de desempacotamento têm que ser repetidas,
-- eles são capturados na definição do >>=. 

-- Assumindo então tipo que representa sucesso e falha no resultado de uma função,
-- definimos os operadores básicos e os extras da classe Monad.

data Maybee a = Nothingg | Justt a

instance Monad Maybee where
    Justt x >>= k  =  k x
    Nothingg >>= _ =  Nothingg

    Justt _ >> k   =  k
    Nothingg >> _  =  Nothingg

    return x      =  Justt x

    fail _        =  Nothingg


instance (Show a) => Show(Maybee a) where
    show (Justt x) = "Just " ++ (show x)
    show Nothingg = "Nothing!" 


-- Função auxiliar útil.

maybee :: b -> (a -> b) -> Maybee a -> b
maybee n _ Nothingg  = n
maybee _ f (Justt x) = f x


-- Podemos então compor funções que podem resultar em erro.

mf :: a -> Maybee b
mf a = Nothingg
mg :: b -> Maybee b
mg b = Justt b

-- Com o uso de monads, primeiro evita-se que as funções recebam Maybe;
-- segundo facilita o encadeamento.

mF a = (mf a) >>= mg >>= mg


-- Complicando um pouco mais com Either

data  Eitherr a b  =  Leftt a | Rightt b
  deriving (Eq, Ord, Read, Show)

instance Monad (Eitherr e) where
    return = Rightt
    Leftt  l >>= _ = Leftt l
    Rightt r >>= k = k r
          
eitherr                  :: (a -> c) -> (b -> c) -> Eitherr a b -> c
eitherr f _ (Leftt x)     =  f x
eitherr _ g (Rightt y)    =  g y

