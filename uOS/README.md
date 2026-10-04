# ⭕ uOS
Micro-OS est écrit entièrement en assembleur avec les fonctionnalités suivantes:
* Cadencement matériel fixé à 100 µS quel que soit la vitesse du µC indiquant à l'état bas le temps d'occupation des traitements sous It
    * Cela permet à la fois de vérifier que le µC déroule bien le programme pour lequel les temporisations et les cadencements internes sont conformes cette vitesse du processeur (8 MHz, 16 MHz ou 20 MHz supportés)
    * De plus, cela indique que le temps passé dans les traitements des Its s'effectuent dans un temps très inférieur à ces 100 µS (typiquement le temps d'occupation n'excède pas 15 µS dans la version publiée ici de uOS) 
* Gestion de 4 Leds:
    * Led verte allumée fugitivement pour l'activité en fond de tâche et la prise compte des commandes émises par UsbMonitor
    * Led jaune allumée fugitivement pour la détection des appuis boutons ou lors de l'émission de caractères vers UsbMonitor
    * Led rouge allumée fugitivement ou en permanence suivant la source de l'erreur (commande reçue non supportée, appui simultané sur 2 boutons, erreur interne à acquitter par un appui bouton ou un RESET dans d'une erreur irrécupérable du µC)
    * Led bleue en réserve (non utilisée par uOS)
* Gestion de 4 boutons avec le support des anti-rebonds, de l'appui court ou long sur un unique bouton
    * 📔 L'appui simultané sur 2 boutons n'est pas supporté et produira un allumage de la led rouge
    * Á noter que uOS utilise dans la version publiée ici 6 *timers* pour:
* Gestion de 16 *timers* logiciel sur 16 bits du type *callback* avec une résolution de 1 mS
    * 📔 Á noter que uOS utilise 6 *timers* pour:
         * L'activité en fond de tâche
         * L'allumage fugitf de la Led rouge en cas d'erreurs
         * L'allumage fugitif de la Led jaune suite à l'appui sur un bouton
         * La détection des appuis bouton
         * L'allumage fugitif de la Led verte 
* Gestion d'une liaison UART *full duplex* de 300 bauds à 19200 bauds définis dans l'EEPROM (9600 bauds par defaut) et reconfigurable à chaud
* Gestion des 2 interruptions *TIMER1_COMPA* et *PCINT0*
* Support des commandes permettant notamment:
    * Le *dump* du programme à partir d'une adresse donnée
    * Le calcul du [CRC8-MAXIM](https://crccalc.com/?crc=123456789&method=CRC-8/MAXIM-DOW&datatype=hex&outtype=hex) du programme *flashé* à des fins de vérification
    * La lecture et l'écriture dans la SRAM
    * La lecture et l'écriture dans l'EEPROM
    * La lecture de la signature et des fusibles
    * La reconfiguration de la vitesse de l'UART
    * Cf. le fichier [Commandes/Réponses](Tests/Commands+Responses.txt) pour la liste exhaustive avec des exemples

## 📎 Applications
uOS permet de développer des programmes utilisant ses ressources sans avoir à les réécrire comme:

## 🛄 Organisation du projet
uOS est organisé au sein des fichiers suivants dont les sources sont fournis:
* **ATmega328p_uOS.asm**, **ATmega328p_uOS.txt** et **ATmega328p_uOS.h**
     * Programme principal exécuté au RESET et incluant tous les fichiers qui suivent
     * Prise en charge des 2 interruptions dans l'implémentation logicielle de l'UART
          * *TIMER1_COMPA* pour le cadencement matériel et gestion de l'UART
          * *PCINT0* pour la gestion des changements d'états de l'UART/Rx et des boutons
     * Prise en charge des 3 interruptions dans l'implémentation matérielle de l'UART
          * *TIMER1_COMPA* pour le cadencement matériel
          * *PCINT0* pour la gestion des changements d'états de l'UART/Rx et des boutons
     * Le fichier '.txt' implémente toutes les constantes définies dans le '.asm'
     * 📔 La chaine de production du '.hex' n'utilise pas d'éditeur de liens
* **ATmega328p_uOS.def**
     * Macros pour la gestion du port de sortie (Leds, UART/Tx, etc.)
* **ATmega328p_uOS_Misc.asm**, **ATmega328p_uOS_Misc.txt** et **ATmega328p_uOS_Misc.h**
     * Méthodes diverses
          * Initialisation de la SRAM
          * Initialisation matérielle
          * Calcul du CRC8-MAXIM
          * Test Leds
          * etc. 
     * Le fichier '.txt' implémente toutes les constantes définies dans le '.asm'
* **ATmega328p_Uart.asm** et **ATmega328p_uOS.h**
     * Gestion de l'UART/Rx et UART/Tx *full duplex* au travers de 2 FIFO/Rx et FIFO/Tx
* **ATmega328p_uOS_Commands.asm**, **ATmega328p_uOS_Commands.txt** et **ATmega328p_uOS_Commands.h**
     * Gestion des commandes/réponses
     * Le fichier '.txt' implémente toutes les constantes définies dans le '.asm'
* **ATmega328p_uOS_Print.asm**, **ATmega328p_uOS_Print.txt** et **ATmega328p_uOS_Print.h**
     * Formatage des émissions (textes, données décimales et hexadécimales, ...)
     * Le fichier '.txt' implémente toutes les constantes définies dans le '.asm'
* **ATmega328p_uOS_Buttons.asm** et **ATmega328p_uOS_Buttons.h**
* **ATmega328p_uOS_Timers.asm** et **ATmega328p_uOS_Timers.h**

## ⚓ Occupations mémoires

## 🛠️ Environnement de développement
* [Assembler for the Atmel AVR microcontroller family](https://github.com/Ro5bert/avra) légèrement modifié pour:
    * Accueillir les sauts **rjmp** et appels **rcall** relatifs
    * Ajouter des messages de *warning* comme:
        * "*ATmega328p_uOS.asm(TODO) : Warning : Improve: Replace absolute by a relative branch (-2048 <= k <= 2047)*"
        * "*ATmega328p_uOS.asm(TODO) : Warning : Improve: Skip equal to 0*"
    * *Á compléter*
* Script *shell* [goGenerateProject.sh](goGenerateProject.sh) fourni pour l'assemblage et la génération du fichier '.hex' au format [HEX Intel](https://fr.wikipedia.org/wiki/HEX_(Intel))
* Script *shell* [goGenerateProjectAllModes.sh](goGenerateProjectAllModes.sh) fourni pour l'assemblage du projet
* Gestion des sources sous [CVS](https://tuteurs.ens.fr/logiciels/cvs/) permettant de faire évoluer le programme "prudemment" avec notamment:
    * Un retour arrière facilité
    * La différence entre différents développements versionnés
    * La pose d'un marqueur symbolique sur une révision d'un ou plusieurs fichiers
    * La création d'une branche sur le projet
    * etc.
* Développements sous Linux (distribution Ubuntu 24.04.3 LTS)

## ⏳ Évolutions envisagées
- Mise en veille du µC pour limiter la consommation dans le cas d'une alimentation au moyen de piles
- *Á compléter*
